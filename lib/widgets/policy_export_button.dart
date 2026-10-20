import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/policy_file_service.dart';
import 'app_glass.dart';

enum PolicyFileAction { share, save, print }

final policyFileServiceProvider = Provider((ref) => PolicyFileService());

class PolicyExportButton extends ConsumerStatefulWidget {
  final String policyId;
  final String? versionUrl;
  const PolicyExportButton(
      {super.key, required this.policyId, this.versionUrl});

  @override
  ConsumerState<PolicyExportButton> createState() => _PolicyExportButtonState();
}

class _PolicyExportButtonState extends ConsumerState<PolicyExportButton> {
  bool _busy = false;

  Future<void> _export(PolicyFileAction action) async {
    if (_busy) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      final orgId = ref.read(organizationProvider).valueOrNull?.id;
      if (user == null || orgId == null) {
        throw StateError('Please sign in again.');
      }
      final policy = await ref
          .read(policyFileServiceProvider)
          .refresh(orgId, widget.policyId);
      if (!canExportPolicy(user, policy)) {
        throw StateError('You do not have access to this policy.');
      }
      final file = await ref
          .read(policyFileServiceProvider)
          .download(policy, versionUrl: widget.versionUrl);
      if (!mounted) return;
      final activeUser = ref.read(currentUserProvider).valueOrNull;
      if (activeUser?.id != user.id ||
          ref.read(organizationProvider).valueOrNull?.id != orgId ||
          activeUser == null ||
          !canExportPolicy(activeUser, policy)) {
        throw StateError('Your access changed. Please open the policy again.');
      }
      switch (action) {
        case PolicyFileAction.share:
          await Share.shareXFiles(
            [XFile.fromData(file.bytes, mimeType: file.mimeType)],
            fileNameOverrides: [file.name],
            subject: policy.name,
            sharePositionOrigin: origin,
          );
        case PolicyFileAction.save:
          await FilePicker.platform.saveFile(
            dialogTitle: 'Save policy',
            fileName: file.name,
            bytes: file.bytes,
            type: FileType.custom,
            allowedExtensions: [file.extension],
          );
        case PolicyFileAction.print:
          if (!policyFileCanPrint(file.extension)) {
            throw StateError(
                'Share this document to a compatible app to print it.');
          }
          var bytes = file.bytes;
          if (file.extension != 'pdf') {
            final document = pw.Document();
            document.addPage(pw.Page(
                build: (_) =>
                    pw.Center(child: pw.Image(pw.MemoryImage(bytes)))));
            bytes = await document.save();
          }
          await Printing.layoutPdf(
              name: file.name, onLayout: (_) async => bytes);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Could not export this policy. Check your access and connection, then try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = ref.watch(policyProvider(widget.policyId)).valueOrNull;
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (policy == null || user == null || !canExportPolicy(user, policy)) {
      return const SizedBox.shrink();
    }
    if (_busy) {
      return const SizedBox(
        width: kMinInteractiveDimension,
        height: kMinInteractiveDimension,
        child: Center(
            child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppGlassColors.ink),
        )),
      );
    }
    return PopupMenuButton<PolicyFileAction>(
      tooltip: 'Share, save or print policy',
      onSelected: _export,
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: PolicyFileAction.share, child: Text('Share')),
        const PopupMenuItem(
            value: PolicyFileAction.save, child: Text('Save a copy')),
        if (policyFileCanPrint(policyFileExtension(
            policy.fileType, widget.versionUrl ?? policy.fileUrl)))
          const PopupMenuItem(
              value: PolicyFileAction.print, child: Text('Print')),
      ],
      child: Semantics(
        button: true,
        child: const SizedBox(
          width: kMinInteractiveDimension,
          height: kMinInteractiveDimension,
          child: Center(
            child: AppGlassSurface(
              width: 40,
              height: 40,
              padding: EdgeInsets.zero,
              radius: 20,
              child: Icon(Icons.ios_share_rounded,
                  color: AppGlassColors.ink, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
