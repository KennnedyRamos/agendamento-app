import 'package:agendamento_app/_colors/my_colors.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'events_page.dart';
import 'profile_page.dart'; // Certifique-se de importar a tela de perfil
import 'package:intl/date_symbol_data_local.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                MyColors.azulClaroTon03,
                MyColors.azulClaroTon01,
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MyColors.azulClaroTon01,
              MyColors.azulClaroTon03,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: TableCalendar(
            locale: 'pt_BR',
            shouldFillViewport: true,
            focusedDay: _focusedDay,
            firstDay: DateTime.utc(2010, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            headerStyle: const HeaderStyle(
              leftChevronIcon: Icon(Icons.skip_previous_outlined),
              rightChevronIcon: Icon(Icons.skip_next_outlined),
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            calendarStyle: CalendarStyle(
              cellMargin: const EdgeInsets.all(0),
              selectedTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 20,
              ),
              outsideDaysVisible: true,
              outsideTextStyle: const TextStyle(
                color: Colors.black,
                fontSize: 15,
              ),
              todayTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 20,
              ),
              selectedDecoration: const BoxDecoration(
                color: MyColors.azulEscuroTon02,
                shape: BoxShape.circle,
              ),
              todayDecoration: const BoxDecoration(
                color: Color.fromARGB(255, 84, 146, 188),
                shape: BoxShape.circle,
              ),
              defaultTextStyle: const TextStyle(
                color: Colors.black,
                fontSize: 22,
              ),
              disabledTextStyle: TextStyle(
                color: Colors.black.withOpacity(0.3),
                fontSize: 22,
              ),
            ),
            enabledDayPredicate: (day) {
              return day
                  .isAfter(DateTime.now().subtract(const Duration(days: 1)));
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventsPage(
                      selectedDate: selectedDay,
                    ),
                  ),
                );
              }
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
          ),
        ),
      ),
    );
  }
}
