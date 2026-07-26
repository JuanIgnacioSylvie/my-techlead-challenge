$ErrorActionPreference = "Stop"
$base = "http://localhost:8000/api/v1"
$pass = 0; $fail = 0

function Check($name, $cond) {
    if ($cond) { $script:pass++; Write-Host "PASS  $name" }
    else { $script:fail++; Write-Host "FAIL  $name" }
}

function StatusOf($scriptBlock) {
    try { & $scriptBlock | Out-Null; return 200 }
    catch { return [int]$_.Exception.Response.StatusCode }
}

# 1. Login OK
$login = Invoke-RestMethod -Method Post -Uri "$base/auth/login" -ContentType "application/json" `
    -Body (@{ username = "operador"; password = "Operador123!" } | ConvertTo-Json)
Check "login devuelve token" ($login.access_token.Length -gt 20)
Check "login devuelve datos de usuario" ($login.nombre_usuario -eq "operador" -and $login.expires_in -eq 3600)
$h = @{ Authorization = "Bearer $($login.access_token)" }

# 2. Login credenciales malas -> 401
$st = StatusOf { Invoke-RestMethod -Method Post -Uri "$base/auth/login" -ContentType "application/json" `
    -Body (@{ username = "operador"; password = "incorrecta" } | ConvertTo-Json) }
Check "login incorrecto -> 401" ($st -eq 401)

# 3. Productos sin token -> 401
$st = StatusOf { Invoke-RestMethod -Uri "$base/productos" }
Check "productos sin token -> 401" ($st -eq 401)

# 4. Productos con filtro y paginacion
$prods = Invoke-RestMethod -Uri "$base/productos?nombre=caja&limit=5" -Headers $h
Check "productos filtra por nombre" ($prods.total -eq 2 -and $prods.items.Count -eq 2)
$todos = Invoke-RestMethod -Uri "$base/productos?limit=3&offset=0" -Headers $h
Check "productos pagina (limit=3)" ($todos.items.Count -eq 3 -and $todos.total -eq 8)

# 5. Crear pedido OK (CAJ-001 x2 + FLM-050 x1)
$caj = ($todos = Invoke-RestMethod -Uri "$base/productos?nombre=Caja cart%C3%B3n mediana" -Headers $h).items[0]
$flm = (Invoke-RestMethod -Uri "$base/productos?nombre=Film" -Headers $h).items[0]
$stockAntes = $caj.stock
$body = @{ cliente_id = 1; detalle = @(
        @{ producto_id = $caj.producto_id; cantidad = 2 },
        @{ producto_id = $flm.producto_id; cantidad = 1 }
    ) } | ConvertTo-Json -Depth 5
$pedido = Invoke-RestMethod -Method Post -Uri "$base/pedidos" -Headers $h -ContentType "application/json" -Body $body
Check "crear pedido -> estado Pendiente" ($pedido.estado -eq "Pendiente")
$totalEsperado = 2 * $caj.precio_unitario + 1 * $flm.precio_unitario
Check "crear pedido -> total correcto" ($pedido.total -eq $totalEsperado)

# 6. Stock descontado
$cajDespues = (Invoke-RestMethod -Uri "$base/productos?nombre=Caja cart%C3%B3n mediana" -Headers $h).items[0]
Check "stock descontado tras pedido" ($cajDespues.stock -eq ($stockAntes - 2))

# 7. Detalle del pedido
$det = Invoke-RestMethod -Uri "$base/pedidos/$($pedido.pedido_id)" -Headers $h
Check "detalle pedido completo" ($det.detalle.Count -eq 2 -and $det.cliente_nombre.Length -gt 0)

# 8. Stock insuficiente -> 409 (9999 respeta le=10000 pero excede stock)
$body409 = @{ cliente_id = 1; detalle = @(@{ producto_id = $caj.producto_id; cantidad = 9999 }) } | ConvertTo-Json -Depth 5
$st = StatusOf { Invoke-RestMethod -Method Post -Uri "$base/pedidos" -Headers $h -ContentType "application/json" -Body $body409 }
Check "stock insuficiente -> 409" ($st -eq 409)

# 9. Validacion Pydantic -> 400 (cantidad negativa)
$body400 = @{ cliente_id = 1; detalle = @(@{ producto_id = 1; cantidad = -5 }) } | ConvertTo-Json -Depth 5
$st = StatusOf { Invoke-RestMethod -Method Post -Uri "$base/pedidos" -Headers $h -ContentType "application/json" -Body $body400 }
Check "cantidad negativa -> 400" ($st -eq 400)

# 10. Producto duplicado -> 400
$bodyDup = @{ cliente_id = 1; detalle = @(
        @{ producto_id = 1; cantidad = 1 }, @{ producto_id = 1; cantidad = 2 }
    ) } | ConvertTo-Json -Depth 5
$st = StatusOf { Invoke-RestMethod -Method Post -Uri "$base/pedidos" -Headers $h -ContentType "application/json" -Body $bodyDup }
Check "producto duplicado -> 400" ($st -eq 400)

# 11. Cliente inexistente -> 404
$body404 = @{ cliente_id = 9999; detalle = @(@{ producto_id = 1; cantidad = 1 }) } | ConvertTo-Json -Depth 5
$st = StatusOf { Invoke-RestMethod -Method Post -Uri "$base/pedidos" -Headers $h -ContentType "application/json" -Body $body404 }
Check "cliente inexistente -> 404" ($st -eq 404)

# 12. Pedido inexistente -> 404
$st = StatusOf { Invoke-RestMethod -Uri "$base/pedidos/99999" -Headers $h }
Check "pedido inexistente -> 404" ($st -eq 404)

# 13. PATCH estado -> EnPreparacion
$patch = Invoke-RestMethod -Method Patch -Uri "$base/pedidos/$($pedido.pedido_id)/estado" -Headers $h `
    -ContentType "application/json" -Body (@{ estado = "EnPreparacion" } | ConvertTo-Json)
Check "patch estado -> EnPreparacion" ($patch.estado -eq "EnPreparacion")

# 14. Cancelar repone stock
Invoke-RestMethod -Method Patch -Uri "$base/pedidos/$($pedido.pedido_id)/estado" -Headers $h `
    -ContentType "application/json" -Body (@{ estado = "Cancelado" } | ConvertTo-Json) | Out-Null
$cajFinal = (Invoke-RestMethod -Uri "$base/productos?nombre=Caja cart%C3%B3n mediana" -Headers $h).items[0]
Check "cancelar repone stock" ($cajFinal.stock -eq $stockAntes)

# 15. Transicion invalida (cancelado -> enviado) -> 400
$st = StatusOf { Invoke-RestMethod -Method Patch -Uri "$base/pedidos/$($pedido.pedido_id)/estado" -Headers $h `
    -ContentType "application/json" -Body (@{ estado = "Enviado" } | ConvertTo-Json) }
Check "transicion desde Cancelado -> 400" ($st -eq 400)

# 16. Estado fuera del enum -> 400
$st = StatusOf { Invoke-RestMethod -Method Patch -Uri "$base/pedidos/$($pedido.pedido_id)/estado" -Headers $h `
    -ContentType "application/json" -Body (@{ estado = "Volando" } | ConvertTo-Json) }
Check "estado invalido -> 400" ($st -eq 400)

# 16b. Clientes activos (para el formulario de pedido)
$clientes = Invoke-RestMethod -Uri "$base/clientes" -Headers $h
Check "clientes activos listados" ($clientes.Count -ge 5 -and $clientes[0].nombre.Length -gt 0)

# 17. Metricas
$met = Invoke-RestMethod -Uri "$base/metricas" -Headers $h
Check "metricas resumen por estado" ($met.resumen_por_estado.Count -ge 4)
Check "metricas detalle por cliente" ($met.detalle.Count -ge 5)

# 18. Token invalido -> 401
$st = StatusOf { Invoke-RestMethod -Uri "$base/metricas" -Headers @{ Authorization = "Bearer token.falso.xyz" } }
Check "token invalido -> 401" ($st -eq 401)

Write-Host ""
Write-Host "RESULTADO: $pass PASS / $fail FAIL"
if ($fail -gt 0) { exit 1 }
