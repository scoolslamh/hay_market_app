import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/auth_storage.dart';
import '../../auth/presentation/login_screen.dart';
import 'merchant_home_screen.dart';

class MerchantPendingScreen extends StatefulWidget {
  const MerchantPendingScreen({super.key});

  @override
  State<MerchantPendingScreen> createState() => _MerchantPendingScreenState();
}

class _MerchantPendingScreenState extends State<MerchantPendingScreen> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  final supabase = Supabase.instance.client;
  String _status = 'pending';
  String _marketName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMarketStatus();
  }

  Future<void> _loadMarketStatus() async {
    try {
      final phone = await AuthStorage().getPhone();
      if (phone == null) return;

      final data = await supabase
          .from('markets')
          .select('status, name')
          .or(
            'owner_phone.eq.$phone,owner_phone.eq.0${phone.startsWith('966') ? phone.substring(3) : phone}',
          )
          .limit(1);

      if (data.isNotEmpty && mounted) {
        final market = data.first;
        final status = market['status'] ?? 'pending';

        // إذا تم القبول → انتقل مباشرة لشاشة التاجر
        if (status == 'active') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MerchantHomeScreen()),
            (route) => false,
          );
          return;
        }

        setState(() {
          _status = status;
          _marketName = market['name'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Load market status error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF004D40)),
              )
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_status == 'rejected') return _buildRejected();
    if (_status == 'frozen') return _buildFrozen();
    return _buildPending();
  }

  // ── انتظار ──
  Widget _buildPending() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: Colors.orange,
              size: 56,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "طلبك قيد المراجعة ⏳",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (_marketName.isNotEmpty)
            Text(
              "متجر: $_marketName",
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _primaryDark,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            "تم استلام طلب انضمام متجرك\nسيتم مراجعته وإشعارك بالنتيجة قريباً",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),

          // خطوات
          _buildStep("1", "تم استلام طلبك ✅", true),
          _buildStep("2", "مراجعة البيانات من الإدارة", false),
          _buildStep("3", "إشعارك بالموافقة أو الرفض", false),

          const SizedBox(height: 28),
          _buildWhatsAppButton(),
          const SizedBox(height: 12),
          _buildCheckStatusButton(),
          const SizedBox(height: 12),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  // ── مرفوض ──
  Widget _buildRejected() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cancel_outlined,
              color: Colors.red,
              size: 56,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "تم رفض طلبك ❌",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "نأسف، تم رفض طلب انضمام متجرك\nيمكنك التواصل مع الإدارة لمعرفة السبب",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          _buildWhatsAppButton(),
          const SizedBox(height: 12),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  // ── مجمد ──
  Widget _buildFrozen() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.ac_unit_outlined,
              color: Colors.blue,
              size: 56,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "الحساب مجمد ❄️",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "تم تجميد حسابك مؤقتاً\nيرجى التواصل مع الإدارة لمعرفة السبب",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          _buildWhatsAppButton(),
          const SizedBox(height: 12),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text, bool isDone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Spacer(),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isDone ? _primaryDark : Colors.grey[400],
              fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDone
                  ? _primary.withValues(alpha: 0.1)
                  : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check_circle, color: _primary, size: 18)
                  : Text(
                      number,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppButton() {
    return SizedBox(
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
          "تواصل مع الإدارة",
          style: TextStyle(
            color: Color(0xFF25D366),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCheckStatusButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loadMarketStatus,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text(
          "تحقق من حالة الطلب",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return TextButton(
      onPressed: () async {
        await AuthStorage().logout();
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
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
    );
  }
}
