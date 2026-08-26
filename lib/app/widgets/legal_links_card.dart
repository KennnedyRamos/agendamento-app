import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalLinksCard extends StatelessWidget {
  const LegalLinksCard({super.key});

  static final Uri _privacyPolicyUrl = Uri.parse(
    'https://github.com/KennnedyRamos/agendamento-app/blob/main/docs/PRIVACY_POLICY.md',
  );
  static final Uri _accountDeletionUrl = Uri.parse(
    'https://github.com/KennnedyRamos/agendamento-app/blob/main/docs/ACCOUNT_DELETION.md',
  );

  Future<void> _open(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir este link.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Política de privacidade'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => _open(context, _privacyPolicyUrl),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.person_remove_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('Solicitar exclusão da conta'),
            subtitle: const Text('Veja como excluir sua conta e seus dados'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => _open(context, _accountDeletionUrl),
          ),
        ],
      ),
    );
  }
}
