import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'orderList.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({Key? key}) : super(key: key);

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  bool isSender = true;

  // Text controllers for form fields
  final TextEditingController pickupController = TextEditingController();
  final TextEditingController dropoffController = TextEditingController();
  final TextEditingController dateController = TextEditingController();

  // Sender-specific controllers
  final TextEditingController itemDescriptionController = TextEditingController();
  final TextEditingController weightController = TextEditingController();

  // Traveller-specific controllers
  final TextEditingController vehicleInfoController = TextEditingController();
  final TextEditingController availableSpaceController = TextEditingController();

  @override
  void dispose() {
    pickupController.dispose();
    dropoffController.dispose();
    dateController.dispose();
    itemDescriptionController.dispose();
    weightController.dispose();
    vehicleInfoController.dispose();
    availableSpaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Order',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Sender/Traveller Toggle Tabs
                Row(
                  children: [
                    // Sender Tab
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            isSender = true;
                          });
                        },
                        child: Column(
                          children: [
                            Text(
                              'Sender',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSender ? FontWeight.bold : FontWeight.normal,
                                color: isSender ? Colors.black : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 2,
                              color: isSender ? Colors.indigo[900] : Colors.transparent,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Traveller Tab
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            isSender = false;
                          });
                        },
                        child: Column(
                          children: [
                            Text(
                              'Traveller',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: !isSender ? FontWeight.bold : FontWeight.normal,
                                color: !isSender ? Colors.black : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 2,
                              color: !isSender ? Colors.indigo[900] : Colors.transparent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Conditional subtitle for Traveller view
                if (!isSender)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Enter your trip detials',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[900],
                      ),
                    ),
                  ),

                // Common Fields for both sender and traveller
                buildInputField(
                  controller: pickupController,
                  icon: Icons.place,
                  title: 'Pickup',
                  hint: 'Enter departure city',
                ),
                const SizedBox(height: 12),

                buildInputField(
                  controller: dropoffController,
                  icon: Icons.pin_drop,
                  title: 'Dropoff',
                  hint: 'Enter arrival city',
                ),
                const SizedBox(height: 12),

                // Date field differs slightly between sender and traveller
                buildInputField(
                  controller: dateController,
                  icon: Icons.calendar_today,
                  title: isSender ? 'Select Date' : 'Select Date and time',
                  hint: isSender ? 'Enter Date of pickup' : 'Enter Date and time of pickup',
                  onTap: () => _selectDate(context),
                ),
                const SizedBox(height: 12),

                // Conditional fields based on sender or traveller
                if (isSender) ...[
                  // Sender specific fields
                  buildInputField(
                    controller: itemDescriptionController,
                    icon: Icons.list_alt,
                    title: 'Item Description',
                    hint: 'Description about item',
                  ),
                  const SizedBox(height: 12),
                  buildInputField(
                    controller: weightController,
                    icon: Icons.scale,
                    title: 'Weight of the item',
                    hint: 'Enter Weight of the item',
                    keyboardType: TextInputType.number,
                  ),
                ] else ...[
                  // Traveller specific fields
                  buildInputField(
                    controller: vehicleInfoController,
                    icon: Icons.local_shipping,
                    title: 'Vehicle Info',
                    hint: 'Description about vehicle',
                  ),
                  const SizedBox(height: 12),
                  buildInputField(
                    controller: availableSpaceController,
                    icon: Icons.inventory_2,
                    title: 'Available Space',
                    hint: 'Enter Available Space in the vehicle',
                  ),
                ],

                const SizedBox(height: 24),

                // Place Order Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _placeOrder(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Place Order',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Custom input field widget
  Widget buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String title,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.black54),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.only(top: 4),
          ),
          onTap: onTap,
          readOnly: onTap != null,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  // Date picker logic
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      if (!isSender) {
        // For traveller, also show time picker
        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );

        if (pickedTime != null) {
          setState(() {
            dateController.text =
            '${picked.day}/${picked.month}/${picked.year} ${pickedTime.format(context)}';
          });
        }
      } else {
        setState(() {
          dateController.text = '${picked.day}/${picked.month}/${picked.year}';
        });
      }
    }
  }

  // Place order logic
  void _placeOrder() {
    // Validate fields
    if (pickupController.text.isEmpty ||
        dropoffController.text.isEmpty ||
        dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (isSender) {
      // Validate sender-specific fields
      if (itemDescriptionController.text.isEmpty || weightController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill item description and weight'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Navigate to Order List Screen when validation passes
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderListScreen(
            // pickup: pickupController.text,
            // dropoff: dropoffController.text,
            // date: dateController.text,
          ),
        ),
      );
    } else {
      // Validate traveller-specific fields
      if (vehicleInfoController.text.isEmpty || availableSpaceController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill vehicle info and available space'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show success message for traveller (different flow)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Traveller trip posted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear all fields
      pickupController.clear();
      dropoffController.clear();
      dateController.clear();
      vehicleInfoController.clear();
      availableSpaceController.clear();
    }
  }
}