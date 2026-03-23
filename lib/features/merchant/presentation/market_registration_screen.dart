import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_notification.dart';
import 'merchant_pending_screen.dart';

class MarketRegistrationScreen extends StatefulWidget {
  final String? inviteCode;
  const MarketRegistrationScreen({super.key, this.inviteCode});

  @override
  State<MarketRegistrationScreen> createState() =>
      _MarketRegistrationScreenState();
}

class _MarketRegistrationScreenState extends State<MarketRegistrationScreen> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // Controllers
  final _marketNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _ownerPhoneCtrl = TextEditingController();
  final _licenseNumberCtrl = TextEditingController();
  final _inviteCodeCtrl = TextEditingController();
  final _neighborhoodNameCtrl = TextEditingController(); // ✅ حقل الحي

  // الصور
  File? _licenseImage;
  File? _storeImage;
  String? _licenseImageUrl;
  String? _storeImageUrl;

  // الموقع
  LatLng? _selectedLocation;
  String _addressName = "اضغط لتحديد الموقع";
  GoogleMapController? _mapController;

  // الحي
  List<Map<String, dynamic>> _neighborhoods = [];
  String? _selectedNeighborhoodId;
  String? _selectedNeighborhoodName;

  int _currentStep = 0;
  bool _isLoading = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadNeighborhoods();
    _getCurrentLocation();
    // ✅ تعبئة الكود تلقائياً إذا أُرسل من login_screen
    if (widget.inviteCode != null) {
      _inviteCodeCtrl.text = widget.inviteCode!;
    }
  }

  @override
  void dispose() {
    _marketNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerPhoneCtrl.dispose();
    _licenseNumberCtrl.dispose();
    _inviteCodeCtrl.dispose();
    _neighborhoodNameCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadNeighborhoods() async {
    try {
      final data = await supabase
          .from('neighborhoods')
          .select()
          .order('name', ascending: true);
      if (mounted) {
        setState(() => _neighborhoods = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      debugPrint("Load neighborhoods error: $e");
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final loc = LatLng(pos.latitude, pos.longitude);

      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(loc, 15));
      await _updateLocation(loc);
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  Future<void> _updateLocation(LatLng loc) async {
    setState(() {
      _selectedLocation = loc;
      _addressName = "جاري تحميل العنوان...";
    });
    try {
      final placemarks = await placemarkFromCoordinates(
        loc.latitude,
        loc.longitude,
        localeIdentifier: "ar",
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks[0];
        setState(() {
          _addressName = [
            p.subLocality ?? '',
            p.thoroughfare ?? '',
          ].where((s) => s.isNotEmpty).join('، ');
          if (_addressName.isEmpty) _addressName = "تم تحديد الموقع";
        });
      }
    } catch (_) {
      setState(() => _addressName = "تم تحديد الموقع");
    }
  }

  Future<void> _pickImage(bool isLicense) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() {
      if (isLicense) {
        _licenseImage = File(picked.path);
      } else {
        _storeImage = File(picked.path);
      }
    });
  }

  Future<String?> _uploadImage(File file, String bucket, String name) async {
    try {
      final bytes = await file.readAsBytes();
      final path = "$name/${DateTime.now().millisecondsSinceEpoch}.jpg";
      await supabase.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      return supabase.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      debugPrint("Upload error: $e");
      return null;
    }
  }

  // ── التحقق من كود الدعوة ──
  Future<bool> _verifyInviteCode() async {
    try {
      final data = await supabase
          .from('invite_codes')
          .select()
          .eq('code', _inviteCodeCtrl.text.trim().toUpperCase())
          .eq('is_used', false)
          .maybeSingle();
      return data != null;
    } catch (_) {
      return false;
    }
  }

  // ── إرسال طلب التسجيل ──
  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      // التحقق من كود الدعوة
      final validCode = await _verifyInviteCode();
      if (!validCode) {
        AppNotification.error(context, "كود الدعوة غير صحيح أو مستخدم مسبقاً");
        setState(() => _isLoading = false);
        return;
      }

      // رفع الصور
      if (_licenseImage != null) {
        _licenseImageUrl = await _uploadImage(
          _licenseImage!,
          'market-licenses',
          _ownerPhoneCtrl.text.trim(),
        );
      }
      if (_storeImage != null) {
        _storeImageUrl = await _uploadImage(
          _storeImage!,
          'market-images',
          _ownerPhoneCtrl.text.trim(),
        );
      }

      // إنشاء المتجر
      await supabase.from('markets').insert({
        'name': _marketNameCtrl.text.trim(),
        'owner_name': _ownerNameCtrl.text.trim(),
        'owner_phone': _ownerPhoneCtrl.text.trim(),
        'license_number': _licenseNumberCtrl.text.trim(),
        'license_image_url': _licenseImageUrl ?? '',
        'store_image_url': _storeImageUrl ?? '',
        'lat': _selectedLocation?.latitude,
        'lng': _selectedLocation?.longitude,
        'neighborhood_name': _neighborhoodNameCtrl.text.trim(),
        'status': 'pending',
        'invite_code': _inviteCodeCtrl.text.trim().toUpperCase(),
      });

      // تعليم الكود كمستخدم
      await supabase
          .from('invite_codes')
          .update({
            'is_used': true,
            'used_by': _ownerPhoneCtrl.text.trim(),
            'used_at': DateTime.now().toIso8601String(),
          })
          .eq('code', _inviteCodeCtrl.text.trim().toUpperCase());

      // تحديث role المستخدم
      await supabase
          .from('users')
          .update({'role': 'merchant'})
          .eq('phone', _ownerPhoneCtrl.text.trim());

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MerchantPendingScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      AppNotification.error(context, "حدث خطأ: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "تسجيل متجر جديد",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── مؤشر الخطوات ──
          _buildStepIndicator(),

          // ── المحتوى ──
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1BasicInfo(),
                _buildStep2Location(),
                _buildStep3Images(),
              ],
            ),
          ),

          // ── أزرار التنقل ──
          _buildNavButtons(),
        ],
      ),
    );
  }

  // ── مؤشر الخطوات ──
  Widget _buildStepIndicator() {
    final steps = ['البيانات', 'الموقع', 'الصور'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: isDone
                              ? _primary
                              : isActive
                              ? _primaryDark
                              : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 15,
                                )
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : Colors.grey[500],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[i],
                        style: TextStyle(
                          fontSize: 10,
                          color: isActive ? _primaryDark : Colors.grey[400],
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18),
                      color: i < _currentStep ? _primary : Colors.grey[200],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── الخطوة 1: البيانات الأساسية ──
  Widget _buildStep1BasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildSectionTitle("البيانات الأساسية"),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _marketNameCtrl,
              label: "اسم المتجر *",
              icon: Icons.store_outlined,
              validator: (v) => v!.isEmpty ? "أدخل اسم المتجر" : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _ownerNameCtrl,
              label: "اسم صاحب المتجر *",
              icon: Icons.person_outline,
              validator: (v) => v!.isEmpty ? "أدخل اسم صاحب المتجر" : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _ownerPhoneCtrl,
              label: "رقم الجوال *",
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => v!.length < 9 ? "أدخل رقم جوال صحيح" : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _licenseNumberCtrl,
              label: "رقم الترخيص التجاري *",
              icon: Icons.badge_outlined,
              validator: (v) => v!.isEmpty ? "أدخل رقم الترخيص" : null,
            ),
            const SizedBox(height: 12),

            // ✅ حقل الحي نصي اختياري
            _buildTextField(
              controller: _neighborhoodNameCtrl,
              label: "الحي الذي يخدمه المتجر (اختياري)",
              icon: Icons.location_city_outlined,
            ),
          ],
        ),
      ),
    );
  }

  // ── الخطوة 2: الموقع ──
  Widget _buildStep2Location() {
    return Column(
      children: [
        // العنوان أعلى الشاشة
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _addressName,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _selectedLocation != null
                        ? FontWeight.w700
                        : FontWeight.normal,
                    color: _selectedLocation != null
                        ? _primaryDark
                        : Colors.grey[500],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on, color: _primary, size: 18),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey[200]),

        // الخريطة
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation ?? const LatLng(24.7136, 46.6753),
                  zoom: 15,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                onMapCreated: (c) => _mapController = c,
                onTap: _updateLocation,
                markers: _selectedLocation != null
                    ? {
                        Marker(
                          markerId: const MarkerId("market"),
                          position: _selectedLocation!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen,
                          ),
                        ),
                      }
                    : {},
              ),

              // زر موقعي الحالي
              Positioned(
                top: 16,
                left: 16,
                child: GestureDetector(
                  onTap: _getCurrentLocation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryDark,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.my_location, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          "موقعي الحالي",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── الخطوة 3: الصور ──
  Widget _buildStep3Images() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildSectionTitle("صور المتجر"),
          const SizedBox(height: 8),
          Text(
            "الصور مطلوبة للتحقق من هوية المتجر",
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 20),

          // صورة السجل التجاري
          _buildImagePicker(
            title: "صورة السجل التجاري *",
            subtitle: "صورة واضحة للسجل التجاري",
            icon: Icons.document_scanner_outlined,
            image: _licenseImage,
            onTap: () => _pickImage(true),
          ),
          const SizedBox(height: 16),

          // صورة واجهة المتجر
          _buildImagePicker(
            title: "صورة واجهة المتجر *",
            subtitle: "صورة خارجية للمتجر",
            icon: Icons.store_mall_directory_outlined,
            image: _storeImage,
            onTap: () => _pickImage(false),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker({
    required String title,
    required String subtitle,
    required IconData icon,
    required File? image,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: image != null ? _primary : Colors.grey.shade200,
            width: image != null ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: image != null
              ? Stack(
                  children: [
                    Image.file(
                      image,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "تم الاختيار ✓",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "اختر صورة",
                        style: TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── أزرار التنقل ──
  Widget _buildNavButtons() {
    final isLastStep = _currentStep == 2;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _currentStep--);
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "رجوع",
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : isLastStep
                  ? _submit
                  : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryDark,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isLastStep ? "إرسال الطلب 🚀" : "التالي",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    // التحقق من الخطوة الأولى
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;
      // ✅ الحي اختياري — لا تحقق مطلوب
    }
    // التحقق من الخطوة الثانية
    if (_currentStep == 1 && _selectedLocation == null) {
      AppNotification.warning(context, "الرجاء تحديد الموقع على الخريطة");
      return;
    }
    // التحقق من الخطوة الثالثة
    if (_currentStep == 1 && _selectedLocation == null) {
      AppNotification.warning(context, "الرجاء تحديد الموقع على الخريطة");
      return;
    }
    if (_currentStep == 2) {
      if (_licenseImage == null) {
        AppNotification.warning(context, "الرجاء إضافة صورة السجل التجاري");
        return;
      }
      if (_storeImage == null) {
        AppNotification.warning(context, "الرجاء إضافة صورة واجهة المتجر");
        return;
      }
    }

    setState(() => _currentStep++);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      textAlign: TextAlign.right,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _primaryDark),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}
