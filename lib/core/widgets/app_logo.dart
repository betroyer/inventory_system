import 'package:flutter/material.dart';

class AppAssets {
  static const logo = 'assets/images/invenstory_logo.png';
  static const icon = 'assets/images/app_icon.png';
}

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.height = 56,
    this.iconOnly = false,
  });

  final double height;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      iconOnly ? AppAssets.icon : AppAssets.logo,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class AppSplash extends StatelessWidget {
  const AppSplash({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(height: 120),
              if (message != null) ...[
                const SizedBox(height: 24),
                Text(
                  message!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
