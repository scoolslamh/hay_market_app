import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/auth_storage.dart';
import '../../auth/presentation/login_screen.dart';

class MerchantPendingScreen extends StatelessWidget {
  const MerchantPendingScreen({super.key});

  static const Color _primaryDark = Color(0xFF004D40);
  static const Color _primary = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // أيقونة الانتظار
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: Colors.orange,
                  size: 60,
                ),
              ),
              const SizedBox(height: 30),

              const Text(
                "طلبك قيد المراجعة",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                "تم استلام طلب انضمام متجرك بنجاح\nسيتم مراجعته من قِبل الإدارة وإشعارك بالنتيجة قريباً",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 30),

              // مراحل الموافقة
              _buildStep("1", "تم استلام طلبك", true),
              _buildStep("2", "مراجعة البيانات من الإدارة", false),
              _buildStep("3", "إشعارك بالموافقة أو الرفض", false),

              const SizedBox(height: 30),

              // زر التواصل
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final url = Uri.parse('https://wa.me/966552134846');
                    if (await canLaunchUrl(url)) {
                      launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF25D366)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                  label: const Text(
                    "تواصل مع الإدارة عبر واتساب",
                    style: TextStyle(
                      color: Color(0xFF25D366),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // زر تسجيل الخروج
              TextButton(
                onPressed: () async {
                  await AuthStorage().logout();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: Text(
                  "تسجيل الخروج",
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text, bool isDone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Spacer(),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDone ? _primaryDark : Colors.grey[400],
              fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDone
                  ? _primary.withValues(alpha: 0.1)
                  : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check_circle, color: _primary, size: 20)
                  : Text(
                      number,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
