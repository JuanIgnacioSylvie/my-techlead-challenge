// Arquitectura por capas (Layered + BLoC):
//
// lib/
// ├── core/          # ApiClient (dio + interceptor JWT), TokenStorage, ApiException
// ├── data/          # modelos (fromJson) y repositorios
// └── presentation/  # pantallas + blocs (evento -> estado)
//     ├── login/         # 1. Login (AuthBloc)
//     ├── dashboard/     # 2. Catálogo + búsqueda + métricas (DashboardBloc)
//     ├── pedido/        # 3. Formulario de pedido (PedidoBloc)
//     ├── confirmacion/  # 4. Éxito/error de la transacción
//     └── pedidos/       # 5. Listado + detalle/cambio de estado (PedidosBloc)

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/api_client.dart';
import 'core/token_storage.dart';
import 'data/repositories.dart';
import 'presentation/login/auth_bloc.dart';
import 'presentation/login/login_screen.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    const tokenStorage = TokenStorage();
    final apiClient = ApiClient(tokenStorage: tokenStorage);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (_) => AuthRepository(api: apiClient, tokens: tokenStorage),
        ),
        RepositoryProvider(create: (_) => CatalogoRepository(api: apiClient)),
        RepositoryProvider(create: (_) => PedidosRepository(api: apiClient)),
        RepositoryProvider(create: (_) => MetricasRepository(api: apiClient)),
      ],
      child: BlocProvider(
        create: (context) =>
            AuthBloc(authRepository: context.read<AuthRepository>()),
        child: MaterialApp(
          title: 'Gestión de Pedidos',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
          home: const LoginScreen(),
        ),
      ),
    );
  }
}
