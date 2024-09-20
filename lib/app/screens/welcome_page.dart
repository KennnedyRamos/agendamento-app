import 'package:agendamento_app/_colors/my_colors.dart';
import 'package:agendamento_app/app/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _showWelcome = true;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _showWelcome = false;
      });
    });

    Timer(const Duration(seconds: 6), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: Center(
          child: _showWelcome
              ? const Text(
                  "Bem-vindo!",
                  style: TextStyle(
                    fontSize: 24,
                    color: MyColors.azulEscuroTon01,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          MyColors.azulEscuroTon01),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Carregando...",
                      style: TextStyle(
                        fontSize: 24,
                        color: MyColors.azulEscuroTon01,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
