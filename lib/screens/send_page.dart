import 'package:flutter/material.dart';

import '../Constants/colorconstant.dart';

void main() => runApp(MaterialApp(home: SendPage()));

class SendPage extends StatefulWidget {
  const SendPage({Key? key}) : super(key: key);
  @override
  _SendPageState createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  List<bool> isSelected = [true, false];

  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController dateController = TextEditingController();

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        dateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'assets/images/doloooo.png',
                      height: 40,
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      iconSize: 28,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              buildSenderTravellerToggle(),
              const SizedBox(height: 30),
              const Text(
                'Enter your trip details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary
                ),
              ),
              const SizedBox(height: 20),
              buildInputBox('From', fromController, Icons.location_on),
              const SizedBox(height: 15),
              buildInputBox('To', toController, Icons.location_on),
              const SizedBox(height: 15),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: buildInputBox('Departure', dateController, Icons.calendar_today),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: 260,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Implement search logic here
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Find a trip',
                    style: TextStyle(fontSize: 16, color:Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Image.asset(
                'assets/images/truck.png',
                height: 130,
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'How it works',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 5),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 80.0),
                child: Text(
                  'Describe a package, find a traveler going the same route, and get it delivered.',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildInputBox(String label, TextEditingController controller, IconData icon) {
    return Container(
      width: 320,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          style: const TextStyle(fontSize: 16, color: Colors.black),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.black54),
            icon: Icon(icon, color: Colors.black),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget buildSenderTravellerToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        buildToggleTab('Sender', 0),
        const SizedBox(width: 12),
        buildToggleTab('Traveller', 1),
      ],
    );
  }

  Widget buildToggleTab(String title, int index) {
    bool selected = isSelected[index];
    return GestureDetector(
      onTap: () {
        setState(() {
          isSelected = [index == 0, index == 1];
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 140,
        height: 45,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
