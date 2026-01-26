import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../widgets/bottom_nav.dart';
import '../utils/mock_data.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connectedDevice = AppMockState.connectedDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartHeart Care'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // reset state ตอน logout (optional แต่ดูโปร)
              AppMockState.connectedDevice = null;
              AppMockState.isMonitoring = false;

              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
          ),
        ],
      ),

      bottomNavigationBar: const BottomNav(currentIndex: 0),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: connectedDevice == null
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: connectedDevice == null
                      ? Colors.red.shade100
                      : Colors.green.shade200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: connectedDevice == null
                        ? Colors.red.shade100.withOpacity(0.5)
                        : Colors.green.shade100.withOpacity(0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device Status:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: connectedDevice == null
                          ? Colors.red.shade300
                          : Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          connectedDevice == null
                              ? Icons.link_off
                              : Icons.check_circle_outline,
                          color: connectedDevice == null
                              ? Colors.red
                              : Colors.green,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              connectedDevice == null
                                  ? 'Not Connected'
                                  : 'Device Connected',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: connectedDevice == null
                                    ? Colors.red.shade800
                                    : Colors.green.shade800,
                              ),
                            ),
                            if (connectedDevice != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                connectedDevice,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Menu Options (Big Cards)
            _buildBigMenuCard(
              context,
              title: 'Connect Device',
              subtitle: 'Scan and pair Bluetooth',
              icon: Icons.bluetooth_searching,
              color: Colors.blue,
              onTap: () => Navigator.pushNamed(context, AppRoutes.bluetooth),
            ),
            const SizedBox(height: 20),
            _buildBigMenuCard(
              context,
              title: 'Start ECG',
              subtitle: 'Measure your heart',
              icon: Icons.monitor_heart,
              color: connectedDevice == null ? Colors.grey : Colors.red,
              isLocked: connectedDevice == null,
              onTap: connectedDevice == null
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please connect device first'),
                      ),
                    )
                  : () => Navigator.pushNamed(context, AppRoutes.monitoring),
            ),
            const SizedBox(height: 20),
            _buildBigMenuCard(
              context,
              title: 'View History',
              subtitle: 'Check previous results',
              icon: Icons.history,
              color: Colors.orange,
              onTap: () => Navigator.pushNamed(context, AppRoutes.history),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBigMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return Material(
      color: isLocked ? Colors.grey.shade50 : Colors.white,
      elevation: isLocked ? 0 : 4,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLocked ? Colors.grey.shade200 : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isLocked
                      ? Colors.grey.shade200
                      : color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isLocked ? Colors.grey : color,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isLocked ? Colors.grey : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 15,
                        color: isLocked ? Colors.grey : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: isLocked ? Colors.grey.shade300 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
