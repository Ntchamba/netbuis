import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Écran vide qui renvoie aussitôt vers [path] : pour une étape ouverte à la main alors
/// qu'elle n'existe pas pour le type de compte choisi (ou qu'il manque un choix préalable).
class BusinessStepRedirect extends StatefulWidget {
  const BusinessStepRedirect(this.path, {super.key});

  final String path;

  @override
  State<BusinessStepRedirect> createState() => _BusinessStepRedirectState();
}

class _BusinessStepRedirectState extends State<BusinessStepRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(widget.path);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}
