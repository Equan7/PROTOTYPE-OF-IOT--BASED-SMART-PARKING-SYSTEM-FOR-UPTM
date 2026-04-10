import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// MODEL USER - UPDATED TO ADD userType
class User {
  final String name;
  final String email;
  final String studentId;
  final String phone;
  final String vehicleNo;
  final String password;
  final String userType; // 'student' or 'lecturer'

  User({
    required this.name,
    required this.email,
    required this.studentId,
    required this.phone,
    required this.vehicleNo,
    required this.password,
    required this.userType,
  });
}

// MODEL PARKING SPOT - SAME AS BEFORE
class ParkingSpot {
  final int id;
  String status; // 'available', 'occupied', 'reserved'
  final String location;
  String lastUpdated;
  String? reservedBy;
  DateTime? reservationTime;
  int? reservationDuration;

  ParkingSpot({
    required this.id,
    required this.status,
    required this.location,
    required this.lastUpdated,
    this.reservedBy,
    this.reservationTime,
    this.reservationDuration,
  });
}

// PARKING MODEL - SAME AS BEFORE
class ParkingModel with ChangeNotifier {
  List<ParkingSpot> _parkingSpots = [];
  List<ParkingSpot> get parkingSpots => _parkingSpots;

  int get availableSpots => _parkingSpots.where((spot) => spot.status == 'available').length;
  int get occupiedSpots => _parkingSpots.where((spot) => spot.status == 'occupied').length;
  int get reservedSpots => _parkingSpots.where((spot) => spot.status == 'reserved').length;
  
  int? get firstAvailableSpot {
    final available = _parkingSpots.firstWhere(
      (spot) => spot.status == 'available',
      orElse: () => ParkingSpot(id: -1, status: '', location: '', lastUpdated: ''),
    );
    return available.id != -1 ? available.id : null;
  }

  void initialize() {
    _parkingSpots = [
      ParkingSpot(
        id: 1,
        status: 'available',
        location: 'Bangunan CS',
        lastUpdated: DateTime.now().toString(),
      ),
      ParkingSpot(
        id: 2,
        status: 'available',
        location: 'Bangunan Sains Komputer',
        lastUpdated: DateTime.now().toString(),
      ),
      ParkingSpot(
        id: 3,
        status: 'occupied',
        location: 'Bangunan Sains Komputer',
        lastUpdated: DateTime.now().toString(),
      ),
      ParkingSpot(
        id: 4,
        status: 'available',
        location: 'Bangunan CS',
        lastUpdated: DateTime.now().toString(),
      ),
      ParkingSpot(
        id: 5,
        status: 'reserved',
        location: 'Bangunan Sains Komputer',
        lastUpdated: DateTime.now().toString(),
        reservedBy: 'AM2408016628',
        reservationTime: DateTime.now().subtract(Duration(minutes: 10)),
        reservationDuration: 30,
      ),
    ];
    notifyListeners();
  }

  void markAsOccupied(int spotId) {
    final spotIndex = _parkingSpots.indexWhere((spot) => spot.id == spotId);
    if (spotIndex != -1) {
      _parkingSpots[spotIndex].status = 'occupied';
      _parkingSpots[spotIndex].lastUpdated = DateTime.now().toString();
      notifyListeners();
    }
  }

  void markAsAvailable(int spotId) {
    final spotIndex = _parkingSpots.indexWhere((spot) => spot.id == spotId);
    if (spotIndex != -1) {
      _parkingSpots[spotIndex].status = 'available';
      _parkingSpots[spotIndex].lastUpdated = DateTime.now().toString();
      _parkingSpots[spotIndex].reservedBy = null;
      _parkingSpots[spotIndex].reservationTime = null;
      _parkingSpots[spotIndex].reservationDuration = null;
      notifyListeners();
    }
  }

  Future<void> reserveSpot(int spotId, String studentId, int duration) async {
    final spotIndex = _parkingSpots.indexWhere((spot) => spot.id == spotId);
    if (spotIndex != -1 && _parkingSpots[spotIndex].status == 'available') {
      _parkingSpots[spotIndex].status = 'reserved';
      _parkingSpots[spotIndex].reservedBy = studentId;
      _parkingSpots[spotIndex].reservationTime = DateTime.now();
      _parkingSpots[spotIndex].reservationDuration = duration;
      _parkingSpots[spotIndex].lastUpdated = DateTime.now().toString();
      notifyListeners();
    }
  }

  Future<void> cancelReservation(int spotId) async {
    final spotIndex = _parkingSpots.indexWhere((spot) => spot.id == spotId);
    if (spotIndex != -1 && _parkingSpots[spotIndex].status == 'reserved') {
      _parkingSpots[spotIndex].status = 'available';
      _parkingSpots[spotIndex].reservedBy = null;
      _parkingSpots[spotIndex].reservationTime = null;
      _parkingSpots[spotIndex].reservationDuration = null;
      _parkingSpots[spotIndex].lastUpdated = DateTime.now().toString();
      notifyListeners();
    }
  }

  bool isReservedByUser(int spotId, String studentId) {
    final spot = _parkingSpots.firstWhere((spot) => spot.id == spotId);
    return spot.status == 'reserved' && spot.reservedBy == studentId;
  }

  List<int> getUserReservations(String studentId) {
    return _parkingSpots
        .where((spot) => spot.status == 'reserved' && spot.reservedBy == studentId)
        .map((spot) => spot.id)
        .toList();
  }

  String getRemainingTime(int spotId) {
    final spot = _parkingSpots.firstWhere((spot) => spot.id == spotId);
    if (spot.reservationTime != null && spot.reservationDuration != null) {
      final endTime = spot.reservationTime!.add(Duration(minutes: spot.reservationDuration!));
      final remaining = endTime.difference(DateTime.now());
      if (remaining.isNegative) return 'Expired';
      return '${remaining.inMinutes}m ${remaining.inSeconds % 60}s';
    }
    return 'Unknown';
  }

  void resetAllSpots() {
    for (var spot in _parkingSpots) {
      spot.status = 'available';
      spot.reservedBy = null;
      spot.reservationTime = null;
      spot.reservationDuration = null;
      spot.lastUpdated = DateTime.now().toString();
    }
    notifyListeners();
  }

  void fillAllSpots() {
    for (var spot in _parkingSpots) {
      spot.status = 'occupied';
      spot.reservedBy = null;
      spot.reservationTime = null;
      spot.reservationDuration = null;
      spot.lastUpdated = DateTime.now().toString();
    }
    notifyListeners();
  }
}

// AUTH SERVICE - UPDATED TO INCLUDE userType
class AuthService {
  User? _currentUser;
  final List<User> _users = [];

  User? get currentUser => _currentUser;

  void addDemoUsers() {
    _users.add(User(
      name: 'Ali Ahmad',
      email: 'ali@uptm.edu.my',
      studentId: 'AM2408016628',
      phone: '012-3456789',
      vehicleNo: 'ABC1234',
      password: 'password123',
      userType: 'student', // Added userType
    ));
    
    // Add a demo lecturer
    _users.add(User(
      name: 'Dr. Sarah',
      email: 'sarah@uptm.edu.my',
      studentId: 'LEC001',
      phone: '013-9876543',
      vehicleNo: 'XYZ7890',
      password: 'lecturer123',
      userType: 'lecturer',
    ));
  }

  Future<bool> login(String studentId, String password) async {
    await Future.delayed(Duration(milliseconds: 500));
    
    final user = _users.firstWhere(
      (user) => user.studentId == studentId,
      orElse: () => User(
        name: '', email: '', studentId: '', phone: '', vehicleNo: '', password: '', userType: ''
      ),
    );
    
    if (user.studentId.isNotEmpty) {
      _currentUser = user;
      return true;
    }
    return false;
  }

  Future<bool> register({
    required String name,
    required String email,
    required String studentId,
    required String phone,
    required String vehicleNo,
    required String password,
    required String userType, // Added userType parameter
  }) async {
    await Future.delayed(Duration(milliseconds: 500));
    
    final existingUser = _users.any((user) => 
      user.email == email || user.studentId == studentId);
    
    if (!existingUser) {
      final newUser = User(
        name: name,
        email: email,
        studentId: studentId,
        phone: phone,
        vehicleNo: vehicleNo,
        password: password,
        userType: userType, // Added userType
      );
      _users.add(newUser);
      _currentUser = newUser;
      return true;
    }
    return false;
  }

  void logout() {
    _currentUser = null;
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ParkingModel()),
        Provider(create: (context) => AuthService()),
      ],
      child: MaterialApp(
        title: 'UPTM Smart Parking',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Inter',
          useMaterial3: true,
        ),
        home: SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// SPLASH SCREEN - SAME AS BEFORE
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AuthScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[900],
      body: Center(
        child: ScaleTransition(
          scale: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.local_parking,
                  size: 60,
                  color: Colors.blue[900],
                ),
              ),
              SizedBox(height: 30),
              Text(
                'UPTM SMART PARKING',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Park with Confidence 🚗',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 50),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// AUTH SCREEN - UPDATED TO INCLUDE STUDENT/LECTURER SELECTION
class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();

  final _loginStudentIdController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regStudentIdController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regVehicleController = TextEditingController();
  final _regPasswordController = TextEditingController();
  
  String _selectedUserType = 'student'; // Default to student

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _authService.addDemoUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[900]!, Colors.blue[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.local_parking, size: 50, color: Colors.white),
                  SizedBox(height: 10),
                  Text(
                    'Welcome to UPTM Parking',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Find your perfect parking spot',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blue[900],
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue[900],
                tabs: [
                  Tab(text: 'LOGIN'),
                  Tab(text: 'REGISTER'),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginTab(),
                  _buildRegisterTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginTab() {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Column(
              children: [
                Text(
                  'Demo Accounts:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900]),
                ),
                SizedBox(height: 10),
                Text('👨‍🎓 Student: AM2408016628 / any password'),
                SizedBox(height: 5),
                Text('👨‍🏫 Lecturer: LEC001 / any password'),
              ],
            ),
          ),
          SizedBox(height: 30),
          
          Container(
            padding: EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _loginStudentIdController,
                  decoration: InputDecoration(
                    labelText: 'Student/Lecturer ID',
                    prefixIcon: Icon(Icons.school, color: Colors.blue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _loginPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock, color: Colors.blue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _handleLogin,
                    child: Text(
                      'LOGIN',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterTab() {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(20),
      child: Container(
        padding: EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // User Type Selection
            Container(
              margin: EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Register As:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedUserType = 'student';
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: _selectedUserType == 'student' 
                                  ? Colors.blue[50] 
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedUserType == 'student' 
                                    ? Colors.blue 
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.school,
                                  color: _selectedUserType == 'student' 
                                      ? Colors.blue 
                                      : Colors.grey,
                                  size: 30,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Student',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _selectedUserType == 'student' 
                                        ? Colors.blue 
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 15),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedUserType = 'lecturer';
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: _selectedUserType == 'lecturer' 
                                  ? Colors.green[50] 
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedUserType == 'lecturer' 
                                    ? Colors.green 
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.person,
                                  color: _selectedUserType == 'lecturer' 
                                      ? Colors.green 
                                      : Colors.grey,
                                  size: 30,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Lecturer',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _selectedUserType == 'lecturer' 
                                        ? Colors.green 
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            TextField(
              controller: _regNameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person, color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: _regEmailController,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email, color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: _regStudentIdController,
              decoration: InputDecoration(
                labelText: _selectedUserType == 'student' ? 'Student ID' : 'Lecturer ID',
                prefixIcon: Icon(Icons.badge, color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: _regPhoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone, color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: _regVehicleController,
              decoration: InputDecoration(
                labelText: 'Vehicle Number',
                prefixIcon: Icon(Icons.directions_car, color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: _regPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock, color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _handleRegister,
                child: Text(
                  'REGISTER NOW',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedUserType == 'student' ? Colors.blue : Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogin() async {
    final success = await _authService.login(
      _loginStudentIdController.text.trim(),
      _loginPasswordController.text.trim(),
    );

    if (success) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ParkingHomePage()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Login failed. Please check your credentials.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleRegister() async {
    if (_regNameController.text.isEmpty ||
        _regEmailController.text.isEmpty ||
        _regStudentIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Please fill in all required fields.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await _authService.register(
      name: _regNameController.text.trim(),
      email: _regEmailController.text.trim(),
      studentId: _regStudentIdController.text.trim(),
      phone: _regPhoneController.text.trim(),
      vehicleNo: _regVehicleController.text.trim(),
      password: _regPasswordController.text.trim(),
      userType: _selectedUserType, // Added userType
    );

    if (success) {
      _tabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Registration successful! Please login.'),
          backgroundColor: Colors.green,
        ),
      );
      
      _regNameController.clear();
      _regEmailController.clear();
      _regStudentIdController.clear();
      _regPhoneController.clear();
      _regVehicleController.clear();
      _regPasswordController.clear();
      setState(() {
        _selectedUserType = 'student';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Registration failed. Email or ID already exists.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// PARKING HOME PAGE - UPDATED TO SHOW USER TYPE
class ParkingHomePage extends StatefulWidget {
  @override
  _ParkingHomePageState createState() => _ParkingHomePageState();
}

class _ParkingHomePageState extends State<ParkingHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ParkingModel>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('🏍️ UPTM Smart Parking'),
        backgroundColor: Colors.blue[900],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              Provider.of<ParkingModel>(context, listen: false).initialize();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleAppBarMenu(value, context),
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue),
                    SizedBox(width: 10),
                    Text('Profile: ${user?.name ?? 'Guest'}'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'my_reservations',
                child: Row(
                  children: [
                    Icon(Icons.bookmark, color: Colors.orange),
                    SizedBox(width: 10),
                    Text('My Reservations'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reset_all',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.green),
                    SizedBox(width: 10),
                    Text('Reset All Spots'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'fill_all',
                child: Row(
                  children: [
                    Icon(Icons.local_parking, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Fill All Spots'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<ParkingModel>(
        builder: (context, parkingModel, child) {
          return Container(
            color: Colors.grey[50],
            child: Column(
              children: [
                // Header Info - FIXED HEIGHT
                _buildHeaderInfo(parkingModel, user),
                
                // User Info
                if (user != null) _buildUserInfo(user, parkingModel),
                
                // Manual Controls
                _buildManualControls(parkingModel),
                
                // Parking Spots List - GUNA EXPANDED
                Expanded(
                  child: _buildParkingList(parkingModel, user),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🆕 FIXED SCROLL VERSION
  Widget _buildParkingList(ParkingModel parkingModel, User? user) {
    if (parkingModel.parkingSpots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading parking data...'),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: AlwaysScrollableScrollPhysics(), // 🆕 FIX SCROLL
      padding: EdgeInsets.only(bottom: 20), // 🆕 ADD BOTTOM PADDING
      itemCount: parkingModel.parkingSpots.length,
      itemBuilder: (context, index) {
        return _buildParkingSpotCard(parkingModel.parkingSpots[index], parkingModel, user);
      },
    );
  }

  Widget _buildUserInfo(User user, ParkingModel parkingModel) {
    final userReservations = parkingModel.getUserReservations(user.studentId);
    final userTypeIcon = user.userType == 'student' 
        ? Icons.school 
        : Icons.person;
    final userTypeColor = user.userType == 'student' 
        ? Colors.blue 
        : Colors.green;
    
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: userTypeColor.withOpacity(0.1),
            child: Icon(userTypeIcon, color: userTypeColor),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Row(
                  children: [
                    Text(
                      user.studentId,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: userTypeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user.userType.toUpperCase(),
                        style: TextStyle(
                          color: userTypeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (userReservations.isNotEmpty)
                  Text(
                    '${userReservations.length} active reservation(s)',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (userReservations.isNotEmpty)
            Icon(Icons.bookmark, color: Colors.orange),
        ],
      ),
    );
  }

  Widget _buildManualControls(ParkingModel parkingModel) {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange[100]!),
      ),
      child: Column(
        children: [
          Text(
            '🧪 MANUAL CONTROL PANEL',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800]),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildControlButton(
                icon: Icons.play_arrow,
                label: 'Car Masuk',
                color: Colors.green,
                onPressed: () => _simulateCarArrival(parkingModel),
              ),
              _buildControlButton(
                icon: Icons.stop,
                label: 'Car Keluar', 
                color: Colors.red,
                onPressed: () => _simulateCarKeluar(parkingModel),
              ),
              _buildControlButton(
                icon: Icons.electric_car,
                label: 'Find Spot',
                color: Colors.blue,
                onPressed: () => _findNearestSpot(parkingModel),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '📱 Real-time Updates | 🎯 Smart Features Active',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildHeaderInfo(ParkingModel parkingModel, User? user) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[900]!, Colors.blue[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Text(
            'PARKING STATUS - LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '📍 Bangunan Sains Komputer',
            style: TextStyle(color: Colors.white70),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusCount('TOTAL', '5', Colors.white),
              _buildStatusCount('BOLEH', '${parkingModel.availableSpots}', Colors.green[300]!),
              _buildStatusCount('PENUH', '${parkingModel.occupiedSpots}', Colors.red[300]!),
              _buildStatusCount('TEMPah', '${parkingModel.reservedSpots}', Colors.orange[300]!),
            ],
          ),
          SizedBox(height: 8),
          if (user != null) 
            Text(
              '👋 Welcome, ${user.userType == 'student' ? 'Student' : 'Lecturer'} ${user.name}!',
              style: TextStyle(color: Colors.green[300], fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCount(String title, String count, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: color),
          ),
          child: Center(
            child: Text(
              count,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: 5),
        Text(
          title,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildParkingSpotCard(ParkingSpot spot, ParkingModel parkingModel, User? user) {
    bool isAvailable = spot.status == 'available';
    bool isReserved = spot.status == 'reserved';
    bool isUserReservation = user != null && parkingModel.isReservedByUser(spot.id, user.studentId);
    
    Color statusColor = isAvailable ? Colors.green : 
                       isReserved ? (isUserReservation ? Colors.orange : Colors.orange[300]!) : Colors.red;
                       
    IconData statusIcon = isAvailable ? Icons.check_circle : 
                         isReserved ? Icons.access_time : Icons.error;

    String reservationInfo = '';
    if (isReserved) {
      if (isUserReservation) {
        reservationInfo = 'Your reservation • ${parkingModel.getRemainingTime(spot.id)} left';
      } else {
        reservationInfo = 'Reserved • ${parkingModel.getRemainingTime(spot.id)} left';
      }
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: statusColor),
          ),
          child: Icon(statusIcon, color: statusColor, size: 24),
        ),
        title: Row(
          children: [
            Text(
              'Spot ${spot.id}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (isUserReservation) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'YOURS',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(spot.location),
            if (reservationInfo.isNotEmpty)
              Text(
                reservationInfo,
                style: TextStyle(
                  fontSize: 11,
                  color: isUserReservation ? Colors.orange[800] : Colors.grey[600],
                  fontWeight: isUserReservation ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            Text(
              'Updated: ${_formatTime(spot.lastUpdated)}',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                spot.status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            SizedBox(width: 8),
            if (isAvailable && user != null) 
              IconButton(
                icon: Icon(Icons.bookmark_add, color: Colors.blue),
                onPressed: () => _showReservationDialog(spot, parkingModel, user!),
                tooltip: 'Reserve this spot',
              )
            else if (isUserReservation)
              IconButton(
                icon: Icon(Icons.cancel, color: Colors.red),
                onPressed: () => _cancelReservation(spot.id, parkingModel),
                tooltip: 'Cancel reservation',
              )
            else if (isAvailable)
              IconButton(
                icon: Icon(Icons.directions_car, color: Colors.red),
                onPressed: () => parkingModel.markAsOccupied(spot.id),
                tooltip: 'Simulate Car Park Here',
              )
            else 
              IconButton(
                icon: Icon(Icons.exit_to_app, color: Colors.green),
                onPressed: () => parkingModel.markAsAvailable(spot.id),
                tooltip: 'Simulate Car Leave',
              ),
          ],
        ),
        onTap: () {
          if (isAvailable && user != null) {
            _showReservationDialog(spot, parkingModel, user!);
          }
        },
      ),
    );
  }

  String _formatTime(String dateTimeString) {
    try {
      DateTime dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showReservationDialog(ParkingSpot spot, ParkingModel parkingModel, User user) {
    int selectedDuration = 30;
    List<int> durationOptions = [15, 30, 60, 120];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.access_time, color: Colors.blue),
                SizedBox(width: 10),
                Text('Tempah Spot ${spot.id}'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Pilih tempoh tempahan:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 15),
                
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: durationOptions.map((duration) {
                    bool isSelected = duration == selectedDuration;
                    return ChoiceChip(
                      label: Text(
                        duration <= 60 ? '$duration min' : '${duration ~/ 60} jam',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          selectedDuration = duration;
                        });
                      },
                      selectedColor: Colors.blue[900],
                      backgroundColor: Colors.blue[50],
                      shape: StadiumBorder(),
                    );
                  }).toList(),
                ),
                
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.green),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Spot akan auto release selepas $selectedDuration minit',
                          style: TextStyle(fontSize: 12, color: Colors.green[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('BATAL', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  await parkingModel.reserveSpot(spot.id, user.studentId, selectedDuration);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('✅ Spot ${spot.id} Ditempah!', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('Tempoh: $selectedDuration minit | Lokasi: ${spot.location}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                child: Text(
                  'TEMPAH SEKARANG 🚗',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _cancelReservation(int spotId, ParkingModel parkingModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Text('Cancel Reservation'),
          ],
        ),
        content: Text('Are you sure you want to cancel reservation for Spot $spotId?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('KEEP'),
          ),
          ElevatedButton(
            onPressed: () async {
              await parkingModel.cancelReservation(spotId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Reservation for Spot $spotId cancelled'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: Text('CANCEL'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }

  void _findNearestSpot(ParkingModel parkingModel) {
    final firstAvailable = parkingModel.firstAvailableSpot;
    if (firstAvailable != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎯 Nearest available spot: Spot $firstAvailable'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ No available spots found'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleAppBarMenu(String value, BuildContext context) {
    final parkingModel = Provider.of<ParkingModel>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    switch (value) {
      case 'profile':
        _showUserProfile(authService.currentUser!);
        break;
      case 'my_reservations':
        _showMyReservations(parkingModel, authService.currentUser!);
        break;
      case 'reset_all':
        parkingModel.resetAllSpots();
        break;
      case 'fill_all':
        parkingModel.fillAllSpots();
        break;
      case 'logout':
        authService.logout();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AuthScreen()));
        break;
    }
  }

  void _showUserProfile(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person, color: Colors.blue),
            SizedBox(width: 10),
            Text('User Profile'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileItem('Name', user.name),
            _buildProfileItem('User Type', user.userType.toUpperCase()),
            _buildProfileItem(user.userType == 'student' ? 'Student ID' : 'Lecturer ID', user.studentId),
            _buildProfileItem('Email', user.email),
            _buildProfileItem('Phone', user.phone),
            _buildProfileItem('Vehicle', user.vehicleNo),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  void _showMyReservations(ParkingModel parkingModel, User user) {
    final userReservations = parkingModel.getUserReservations(user.studentId);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.bookmark, color: Colors.orange),
            SizedBox(width: 10),
            Text('My Reservations (${userReservations.length})'),
          ],
        ),
        content: userReservations.isEmpty
            ? Text('You have no active reservations.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: userReservations.map((spotId) {
                  return ListTile(
                    leading: Icon(Icons.local_parking, color: Colors.orange),
                    title: Text('Spot $spotId'),
                    subtitle: Text('Time left: ${parkingModel.getRemainingTime(spotId)}'),
                    trailing: IconButton(
                      icon: Icon(Icons.cancel, color: Colors.red),
                      onPressed: () {
                        Navigator.pop(context);
                        _cancelReservation(spotId, parkingModel);
                      },
                    ),
                  );
                }).toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  void _simulateCarArrival(ParkingModel parkingModel) {
    final firstAvailable = parkingModel.firstAvailableSpot;
    if (firstAvailable != null) {
      parkingModel.markAsOccupied(firstAvailable);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ No available spots for parking'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _simulateCarKeluar(ParkingModel parkingModel) {
    for (var spot in parkingModel.parkingSpots) {
      if (spot.status == 'occupied') {
        parkingModel.markAsAvailable(spot.id);
        break;
      }
    }
  }
}