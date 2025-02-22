import 'package:flutter/material.dart';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:future_loading_dialog/future_loading_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import 'package:fluffychat/widgets/permission_slider_dialog.dart';
import '../../widgets/matrix.dart';
import 'user_bottom_sheet_view.dart';

enum UserBottomSheetAction {
  report,
  mention,
  ban,
  kick,
  unban,
  permission,
  message,
  ignore,
}

class LoadProfileBottomSheet extends StatelessWidget {
  final String userId;
  final BuildContext outerContext;

  const LoadProfileBottomSheet({
    super.key,
    required this.userId,
    required this.outerContext,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileInformation>(
      future: Matrix.of(outerContext)
          .client
          .getUserProfile(userId)
          .timeout(const Duration(seconds: 3)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            snapshot.data != null) {
          return Scaffold(
            appBar: AppBar(
              leading: CloseButton(
                onPressed: Navigator.of(context, rootNavigator: false).pop,
              ),
            ),
            body: const Center(
              child: CircularProgressIndicator.adaptive(),
            ),
          );
        }
        return UserBottomSheet(
          outerContext: outerContext,
          profile: Profile(
            userId: userId,
            avatarUrl: snapshot.data?.avatarUrl,
            displayName: snapshot.data?.displayname,
          ),
          profileSearchError: snapshot.error,
        );
      },
    );
  }
}

class UserBottomSheet extends StatefulWidget {
  final User? user;
  final Profile? profile;
  final Function? onMention;
  final BuildContext outerContext;
  final Object? profileSearchError;

  const UserBottomSheet({
    super.key,
    this.user,
    this.profile,
    required this.outerContext,
    this.onMention,
    this.profileSearchError,
  }) : assert(user != null || profile != null);

  @override
  UserBottomSheetController createState() => UserBottomSheetController();
}

class UserBottomSheetController extends State<UserBottomSheet> {
  void participantAction(UserBottomSheetAction action) async {
    final user = widget.user;
    final userId = user?.id ?? widget.profile?.userId;
    if (userId == null) throw ('user or profile must not be null!');

    switch (action) {
      case UserBottomSheetAction.report:
        if (user == null) throw ('User must not be null for this action!');

        final score = await showConfirmationDialog<int>(
          context: context,
          title: L10n.of(context)!.reportUser,
          message: L10n.of(context)!.howOffensiveIsThisContent,
          cancelLabel: L10n.of(context)!.cancel,
          okLabel: L10n.of(context)!.ok,
          actions: [
            AlertDialogAction(
              key: -100,
              label: L10n.of(context)!.extremeOffensive,
            ),
            AlertDialogAction(
              key: -50,
              label: L10n.of(context)!.offensive,
            ),
            AlertDialogAction(
              key: 0,
              label: L10n.of(context)!.inoffensive,
            ),
          ],
        );
        if (score == null) return;
        final reason = await showTextInputDialog(
          useRootNavigator: false,
          context: context,
          title: L10n.of(context)!.whyDoYouWantToReportThis,
          okLabel: L10n.of(context)!.ok,
          cancelLabel: L10n.of(context)!.cancel,
          textFields: [DialogTextField(hintText: L10n.of(context)!.reason)],
        );
        if (reason == null || reason.single.isEmpty) return;
        final result = await showFutureLoadingDialog(
          context: context,
          future: () => Matrix.of(widget.outerContext).client.reportContent(
                user.roomId!,
                user.eventId,
                reason: reason.single,
                score: score,
              ),
        );
        if (result.error != null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context)!.contentHasBeenReported)),
        );
        break;
      case UserBottomSheetAction.mention:
        if (user == null) throw ('User must not be null for this action!');
        Navigator.of(context, rootNavigator: false).pop();
        widget.onMention!();
        break;
      case UserBottomSheetAction.ban:
        if (user == null) throw ('User must not be null for this action!');
        if (await showOkCancelAlertDialog(
              useRootNavigator: false,
              context: context,
              title: L10n.of(context)!.areYouSure,
              okLabel: L10n.of(context)!.yes,
              cancelLabel: L10n.of(context)!.no,
              message: L10n.of(context)!.banUserDescription,
            ) ==
            OkCancelResult.ok) {
          await showFutureLoadingDialog(
            context: context,
            future: () => user.ban(),
          );
          Navigator.of(context, rootNavigator: false).pop();
        }
        break;
      case UserBottomSheetAction.unban:
        if (user == null) throw ('User must not be null for this action!');
        if (await showOkCancelAlertDialog(
              useRootNavigator: false,
              context: context,
              title: L10n.of(context)!.areYouSure,
              okLabel: L10n.of(context)!.yes,
              cancelLabel: L10n.of(context)!.no,
              message: L10n.of(context)!.unbanUserDescription,
            ) ==
            OkCancelResult.ok) {
          await showFutureLoadingDialog(
            context: context,
            future: () => user.unban(),
          );
          Navigator.of(context, rootNavigator: false).pop();
        }
        break;
      case UserBottomSheetAction.kick:
        if (user == null) throw ('User must not be null for this action!');
        if (await showOkCancelAlertDialog(
              useRootNavigator: false,
              context: context,
              title: L10n.of(context)!.areYouSure,
              okLabel: L10n.of(context)!.yes,
              cancelLabel: L10n.of(context)!.no,
              message: L10n.of(context)!.kickUserDescription,
            ) ==
            OkCancelResult.ok) {
          await showFutureLoadingDialog(
            context: context,
            future: () => user.kick(),
          );
          Navigator.of(context, rootNavigator: false).pop();
        }
        break;
      case UserBottomSheetAction.permission:
        if (user == null) throw ('User must not be null for this action!');
        final newPermission = await showPermissionChooser(
          context,
          currentLevel: user.powerLevel,
        );
        if (newPermission != null) {
          if (newPermission == 100 &&
              await showOkCancelAlertDialog(
                    useRootNavigator: false,
                    context: context,
                    title: L10n.of(context)!.areYouSure,
                    okLabel: L10n.of(context)!.yes,
                    cancelLabel: L10n.of(context)!.no,
                    message: L10n.of(context)!.makeAdminDescription,
                  ) ==
                  OkCancelResult.ok) break;
          await showFutureLoadingDialog(
            context: context,
            future: () => user.setPower(newPermission),
          );
          Navigator.of(context, rootNavigator: false).pop();
        }
        break;
      case UserBottomSheetAction.message:
        final roomIdResult = await showFutureLoadingDialog(
          context: context,
          future: () => Matrix.of(widget.outerContext)
              .client
              .startDirectChat(user?.id ?? widget.profile!.userId),
        );
        if (roomIdResult.error != null) return;
        widget.outerContext.go('/rooms/${roomIdResult.result!}');
        Navigator.of(context, rootNavigator: false).pop();
        break;
      case UserBottomSheetAction.ignore:
        context.go('/rooms/settings/security/ignorelist');
    }
  }

  @override
  Widget build(BuildContext context) => UserBottomSheetView(this);
}
