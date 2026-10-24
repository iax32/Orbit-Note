import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Only a DNS hostname can enter the proxy snippet: never arbitrary config,
/// credentials, paths, ports or shell commands.
String? sharedServerHostname(String input) {
  final value = input.trim().toLowerCase();
  if (value.length > 253 ||
      !value.contains('.') ||
      RegExp(r'^[0-9.]+$').hasMatch(value)) {
    return null;
  }
  final label = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
  return value.split('.').every(label.hasMatch) ? value : null;
}

class SharedServerSetup extends StatefulWidget {
  const SharedServerSetup({super.key, required this.onUseAddress});
  final ValueChanged<String> onUseAddress;

  @override
  State<SharedServerSetup> createState() => _SharedServerSetupState();
}

class _SharedServerSetupState extends State<SharedServerSetup> {
  final domain = TextEditingController();
  bool copied = false;

  @override
  void dispose() {
    domain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hostname = sharedServerHostname(domain.text);
    final config = hostname == null
        ? null
        : '$hostname {\n    reverse_proxy 127.0.0.1:47831\n}\n';
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Set up a host for your devices'),
      subtitle: const Text('Host → HTTPS address → private invitation'),
      childrenPadding: const EdgeInsets.only(bottom: 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Start the host',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const Text(
          'On Windows, open collaboration/Start Orbit Server.cmd beside the app. '
          'Keep its console open. The default private data folder is '
          '%LOCALAPPDATA%\\OrbitNote\\Server. Paste the contents of owner-key.secret '
          'into Server owner key below. Keep that key private and outside every Vault.',
        ),
        const SizedBox(height: 12),
        const Text(
          '2. Reach it from another device',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const Text(
          'Localhost reaches only the device you are using. For other devices, '
          'configure a domain you control and an HTTPS reverse proxy on the host. '
          'The example below is a Caddyfile for the default local port. DNS, TLS '
          'and the firewall must be configured on your host. Keep port 47831 private.',
        ),
        const SizedBox(height: 8),
        TextField(
          controller: domain,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Your host’s domain',
            hintText: 'notes.your-domain.com',
            errorText: domain.text.isNotEmpty && hostname == null
                ? 'Enter a domain only, without https://, paths or ports.'
                : null,
          ),
          onChanged: (_) => setState(() => copied = false),
        ),
        if (config != null) ...[
          const SizedBox(height: 8),
          SelectableText(config),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_outlined),
                label: Text(
                  copied
                      ? 'Proxy configuration copied'
                      : 'Copy proxy configuration',
                ),
                onPressed: () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: config));
                  } on Object {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not copy the configuration. You can select the text above.',
                          ),
                        ),
                      );
                    }
                    return;
                  }
                  if (mounted && domain.text.trim().toLowerCase() == hostname) {
                    setState(() => copied = true);
                  }
                },
              ),
              TextButton(
                onPressed: () => widget.onUseAddress('https://$hostname'),
                child: const Text('Use this HTTPS address'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          '3. Connect and invite',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const Text(
          'Test the HTTPS server connection below before sharing. Share this Vault '
          'uploads its full snapshot, including Archive, Trash and portable history. '
          'Create a separate Editor or Viewer invitation for each person. On another '
          'device, paste that invitation into Join shared Vault and import into a '
          'separate folder. Remember the connection there for explicit reconnect '
          'after restart. Personal Drive sync pauses during shared sessions.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Recovery: stop the server before backing up its entire private data folder. '
          'Keep its owner key and journal together. Never delete the journal or '
          'replace the key to fix a connection. This guide does not install a proxy '
          'or a background service.',
        ),
      ],
    );
  }
}
