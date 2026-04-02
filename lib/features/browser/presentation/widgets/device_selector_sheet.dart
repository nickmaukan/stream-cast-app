import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/cast_device.dart';
import '../../../casting/presentation/bloc/casting_bloc.dart';

class DeviceSelectorSheet extends StatefulWidget {
  const DeviceSelectorSheet({super.key});

  @override
  State<DeviceSelectorSheet> createState() => _DeviceSelectorSheetState();
}

class _DeviceSelectorSheetState extends State<DeviceSelectorSheet> {
  bool _showManualEntry = false;
  final _ipController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CastingBloc>().add(DiscoverDevices());
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _toggleManualEntry() {
    setState(() {
      _showManualEntry = !_showManualEntry;
      if (!_showManualEntry) {
        _ipController.clear();
        _nameController.clear();
      }
    });
  }

  void _connectManual() {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa la dirección IP'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final name = _nameController.text.trim().isNotEmpty 
        ? _nameController.text.trim() 
        : 'Device at $ip';

    final device = CastDevice(
      id: 'manual-$ip',
      name: name,
      host: ip,
      port: 8009,
      type: CastDeviceType.chromecast,
    );

    context.read<CastingBloc>().add(ConnectToDevice(device));
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Conectando a $name...'),
        backgroundColor: AppTheme.secondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            _buildHeader(),
            if (_showManualEntry) _buildManualEntry(),
            Expanded(
              child: BlocBuilder<CastingBloc, CastingBlocState>(
                builder: (context, state) {
                  if (state.isDiscovering) {
                    return _buildSearching();
                  }
                  if (state.devices.isEmpty) {
                    return _buildEmpty();
                  }
                  return _buildDeviceList(state, scrollController);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.cast, color: AppTheme.primary, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conectar a TV',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Dispositivos en tu red',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _showManualEntry ? Icons.close : Icons.add,
              color: Colors.white54,
            ),
            onPressed: _toggleManualEntry,
            tooltip: 'Agregar manualmente',
          ),
          BlocBuilder<CastingBloc, CastingBlocState>(
            builder: (context, state) => IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54),
              onPressed: state.isDiscovering
                  ? null
                  : () => context.read<CastingBloc>().add(DiscoverDevices()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntry() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.router, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Agregar por IP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ipController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Ej: 192.168.1.50',
              hintStyle: const TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.language, color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Nombre (opcional)',
              hintStyle: const TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.edit, color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _connectManual,
              icon: const Icon(Icons.cast),
              label: const Text('Conectar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearching() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Buscando dispositivos...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Esto puede tardar hasta 15 segundos.\nAsegúrate de que tu Chromecast y teléfono estén en la misma red WiFi.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          _buildTipsCard(),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppTheme.warning, size: 20),
              SizedBox(width: 8),
              Text(
                'Tips',
                style: TextStyle(
                  color: AppTheme.warning,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• Verifica que el Chromecast esté encendido\n'
            '• Ambos dispositivos deben estar en la misma red WiFi\n'
            '• Algunas redes de empresa/universidad bloquean el descubrimiento\n'
            '• Prueba reiniciar el router si no aparece ningún dispositivo',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cast_outlined, color: AppTheme.warning, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'No se encontraron dispositivos',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Si conoces la IP de tu Chromecast, agrégala manualmente.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            _buildTipsCard(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.read<CastingBloc>().add(DiscoverDevices()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Buscar de nuevo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.textMuted),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _toggleManualEntry,
                  icon: const Icon(Icons.add),
                  label: const Text('Por IP'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(CastingBlocState state, ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Info about found devices
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Se encontraron ${state.devices.length} dispositivo(s)',
                style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Connected device
        if (state.isConnected) ...[
          _buildConnectedDevice(state),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
        ],

        // Available devices
        ...state.devices
            .where((d) => d.id != state.connectedDevice?.id)
            .map((device) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DeviceTile(
                    device: device,
                    onTap: () => _connectToDevice(device),
                  ),
                )),

        const SizedBox(height: 16),
        const Divider(color: Colors.white12),
        const SizedBox(height: 16),

        // Manual IP entry section
        const Text(
          'CONEXIÓN MANUAL',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Si conoces la IP de tu dispositivo, ingrésala aquí',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 12),
        if (!_showManualEntry)
          OutlinedButton.icon(
            onPressed: _toggleManualEntry,
            icon: const Icon(Icons.add),
            label: const Text('Agregar por IP'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppTheme.textMuted),
            ),
          ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildConnectedDevice(CastingBlocState state) {
    final device = state.connectedDevice!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.secondary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(device.type.icon, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Conectado', style: TextStyle(
                      color: AppTheme.secondary, fontSize: 12, fontWeight: FontWeight.w500,
                    )),
                    const SizedBox(width: 8),
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(device.name, style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold,
                )),
                Text(
                  '${device.type.displayName} • ${device.host}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () => context.read<CastingBloc>().add(DisconnectFromDevice()),
          ),
        ],
      ),
    );
  }

  void _connectToDevice(CastDevice device) async {
    context.read<CastingBloc>().add(ConnectToDevice(device));
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Conectado a ${device.name}'),
          backgroundColor: AppTheme.secondary,
        ),
      );
    }
  }
}

class _DeviceTile extends StatelessWidget {
  final CastDevice device;
  final VoidCallback onTap;

  const _DeviceTile({
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(device.type.icon, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${device.type.displayName}${device.manufacturer != null ? ' • ${device.manufacturer}' : ''}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  Text(
                    device.host,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cast, color: AppTheme.secondary, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
