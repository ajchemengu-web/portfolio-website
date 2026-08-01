import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/responsive.dart';
import '../../data/api_repository.dart';
import '../admin/auth/auth_controller.dart';

class ContactPage extends ConsumerStatefulWidget {
  const ContactPage({super.key});

  @override
  ConsumerState<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends ConsumerState<ContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  bool _submitting = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await submitContactForm(
        ref.read(publicApiClientProvider),
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
      );
      setState(() {
        _successMessage = "Thanks for reaching out — I'll get back to you soon.";
        _nameController.clear();
        _emailController.clear();
        _subjectController.clear();
        _messageController.clear();
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } on ApiUnreachableException {
      setState(() => _errorMessage = 'Could not reach the server. Please try again later, or email me directly.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return Section(
      title: 'Contact',
      subtitle: 'Questions about my research, collaboration ideas, or opportunities — I\'d love to hear from you.',
      child: Flex(
        direction: mobile ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: mobile ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _buildForm(context)),
          SizedBox(width: mobile ? 0 : 32, height: mobile ? 32 : 0),
          Expanded(flex: 2, child: _buildDetails(context)),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name.' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Please enter your email.';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return 'Please enter a valid email.';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _subjectController,
            decoration: const InputDecoration(labelText: 'Subject (optional)'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _messageController,
            decoration: const InputDecoration(labelText: 'Message'),
            maxLines: 6,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a message.' : null,
          ),
          const SizedBox(height: 20),
          if (_successMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_successMessage!, style: TextStyle(color: Colors.green.shade700)),
            ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send Message'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Other ways to reach me', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _ContactRow(
              icon: Icons.email_outlined,
              label: AppConfig.contactEmail,
              onTap: () => launcher.launchUrl(Uri.parse('mailto:${AppConfig.contactEmail}')),
            ),
            _ContactRow(
              icon: Icons.code,
              label: 'GitHub',
              onTap: () => launcher.launchUrl(Uri.parse(AppConfig.githubUrl), webOnlyWindowName: '_blank'),
            ),
            _ContactRow(
              icon: Icons.work_outline,
              label: 'LinkedIn',
              onTap: () => launcher.launchUrl(Uri.parse(AppConfig.linkedinUrl), webOnlyWindowName: '_blank'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      ),
    );
  }
}
