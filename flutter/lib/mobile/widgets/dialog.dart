import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/setting_widgets.dart';
import 'package:flutter_hbb/common/widgets/toolbar.dart';
import 'package:get/get.dart';

import '../../common.dart';
import '../../models/platform_model.dart';

void _showSuccess() {
  showToast(translate("Successful"));
}

void _showError() {
  showToast(translate("Error"));
}

void setPermanentPasswordDialog(OverlayDialogManager dialogManager) async {
  final pw = await bind.mainGetPermanentPassword();
  final p0 = TextEditingController(text: pw);
  final p1 = TextEditingController(text: pw);
  var validateLength = false;
  var validateSame = false;
  dialogManager.show((setState, close, context) {
    submit() async {
      close();
      dialogManager.showLoading(translate("Waiting"));
      if (await gFFI.serverModel.setPermanentPassword(p0.text)) {
        dialogManager.dismissAll();
        _showSuccess();
      } else {
        dialogManager.dismissAll();
        _showError();
      }
    }

    return CustomAlertDialog(
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.password_rounded, color: MyTheme.accent),
          Text(translate('Set your own password')).paddingOnly(left: 10),
        ],
      ),
      content: Form(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                labelText: translate('Password'),
              ),
              controller: p0,
              validator: (v) {
                if (v == null) return null;
                final val = v.trim().length > 5;
                if (validateLength != val) {
                  // use delay to make setState success
                  Future.delayed(Duration(microseconds: 1),
                      () => setState(() => validateLength = val));
                }
                return val
                    ? null
                    : translate('Too short, at least 6 characters.');
              },
            ).workaroundFreezeLinuxMint(),
            TextFormField(
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                labelText: translate('Confirmation'),
              ),
              controller: p1,
              validator: (v) {
                if (v == null) return null;
                final val = p0.text == v;
                if (validateSame != val) {
                  Future.delayed(Duration(microseconds: 1),
                      () => setState(() => validateSame = val));
                }
                return val
                    ? null
                    : translate('The confirmation is not identical.');
              },
            ).workaroundFreezeLinuxMint(),
          ])),
      onCancel: close,
      onSubmit: (validateLength && validateSame) ? submit : null,
      actions: [
        dialogButton(
          'Cancel',
          icon: Icon(Icons.close_rounded),
          onPressed: close,
          isOutline: true,
        ),
        dialogButton(
          'OK',
          icon: Icon(Icons.done_rounded),
          onPressed: (validateLength && validateSame) ? submit : null,
        ),
      ],
    );
  });
}

void setTemporaryPasswordLengthDialog(
    OverlayDialogManager dialogManager) async {
  List<String> lengths = ['6', '8', '10'];
  String length = await bind.mainGetOption(key: "temporary-password-length");
  var index = lengths.indexOf(length);
  if (index < 0) index = 0;
  length = lengths[index];
  dialogManager.show((setState, close, context) {
    setLength(newValue) {
      final oldValue = length;
      if (oldValue == newValue) return;
      setState(() {
        length = newValue;
      });
      bind.mainSetOption(key: "temporary-password-length", value: newValue);
      bind.mainUpdateTemporaryPassword();
      Future.delayed(Duration(milliseconds: 200), () {
        close();
        _showSuccess();
      });
    }

    return CustomAlertDialog(
      title: Text(translate("Set one-time password length")),
      content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: lengths
              .map(
                (value) => Row(
                  children: [
                    Text(value),
                    Radio(
                        value: value, groupValue: length, onChanged: setLength),
                  ],
                ),
              )
              .toList()),
    );
  }, backDismiss: true, clickMaskDismiss: true);
}

void showServerSettings(OverlayDialogManager dialogManager) async {
  Map<String, dynamic> options = {};
  try {
    options = jsonDecode(await bind.mainGetOptions());
  } catch (e) {
    print("Invalid server config: $e");
  }
  showServerSettingsWithValue(ServerConfig.fromOptions(options), dialogManager);
}

void showServerSettingsWithValue(
    ServerConfig serverConfig, OverlayDialogManager dialogManager) async {
  var isInProgress = false;
  final idCtrl = TextEditingController(text: serverConfig.idServer);
  final relayCtrl = TextEditingController(text: serverConfig.relayServer);
  final apiCtrl = TextEditingController(text: serverConfig.apiServer);
  final keyCtrl = TextEditingController(text: serverConfig.key);

  RxString idServerMsg = ''.obs;
  RxString relayServerMsg = ''.obs;
  RxString apiServerMsg = ''.obs;

  final controllers = [idCtrl, relayCtrl, apiCtrl, keyCtrl];
  final errMsgs = [
    idServerMsg,
    relayServerMsg,
    apiServerMsg,
  ];

  final historyConfigs = await loadServerConfigHistory();

  dialogManager.show((setState, close, context) {

    Widget buildField(
        String label, TextEditingController controller, String errorMsg,
        {String? Function(String?)? validator, bool autofocus = false}) {
      if (isDesktop || isWeb) {
        return Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(label),
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  errorText: errorMsg.isEmpty ? null : errorMsg,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                validator: validator,
                autofocus: autofocus,
              ).workaroundFreezeLinuxMint(),
            ),
          ],
        );
      }

      return TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          errorText: errorMsg.isEmpty ? null : errorMsg,
        ),
        validator: validator,
      ).workaroundFreezeLinuxMint();
    }
    final showButtons = true.obs;

    const double singleItemHeight = 72.0; // 每条记录大约72像素
    // 动态计算弹窗高度
    // final double baseHeight = 200.0; // 基础高度（无历史记录时）
    // final double historyHeight = min(
    //   historyConfigs.length * singleItemHeight,
    //   5*singleItemHeight, // 最大不超过屏幕高度的60%
    // );

    final showHistory = false.obs;
    // 使用 Rx 响应式变量存储高度
    final baseHeight = 200.0.obs; // 基础高度（无历史记录时）
    final historyHeight =
        (min(max(historyConfigs.length, 3), 5) * singleItemHeight).obs;

    // 响应 showHistory 变化更新高度
    ever(showHistory, (value) {
      if (value) {
        baseHeight.value = 200.0;
        historyHeight.value =
            min(max(historyConfigs.length, 3), 5) * singleItemHeight;
      } else {
        baseHeight.value = 200.0;
      }
    });
    ever(showHistory, (value) {
      showButtons.value = !value;
    });

    void deleteHistoryConfig(int index) async {
      print("==== index ${index} len ${historyConfigs.length}");
      // 从历史列表中移除指定项
      historyConfigs.removeAt(index-1);

      // 保存更新后的历史记录
      await bind.mainSetOption(
        key: kServerConfigHistory,
        value: jsonEncode(historyConfigs.map((c) => c.toJson()).toList()),
      );

      // 刷新UI
      setState(() {});
    }

    return CustomAlertDialog(
      title: Builder(
        builder: (dialogContext) {
          return Row(
            children: [
              Expanded(child: Text(translate('ID/Relay Server'))),
              ...ServerConfigImportExportWidgets(
                  controllers, errMsgs, historyConfigs, showHistory),
            ],
          );
        },
      ),
      content: Obx(() {
        return ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 500,
            minHeight: showHistory.value
                ? max(baseHeight.value, historyHeight.value*1.2 + 50) // 添加额外高度
                : baseHeight.value,
          ),
          child: Stack(
            // 使用Stack实现层叠布局
            children: [
              // 表单内容
              Form(
                child: Obx(() => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        buildField(
                            translate('ID Server'), idCtrl, idServerMsg.value,
                            autofocus: true),
                        SizedBox(height: 8),
                        if (!isIOS && !isWeb) ...[
                          buildField(translate('Relay Server'), relayCtrl,
                              relayServerMsg.value),
                          SizedBox(height: 8),
                        ],
                        buildField(
                          translate('API Server'),
                          apiCtrl,
                          apiServerMsg.value,
                          validator: (v) {
                            if (v != null && v.isNotEmpty) {
                              if (!(v.startsWith('http://') ||
                                  v.startsWith("https://"))) {
                                return translate("invalid_http");
                              }
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 8),
                        buildField('Key', keyCtrl, ''),
                        if (isInProgress)
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(),
                          ),
                      ],
                    )),
              ),
              Obx(() {
                if (!showHistory.value) return const SizedBox.shrink();

                return Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Material(
                    elevation: 8.0,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: historyHeight.value * 1.2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).dialogBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 标题栏
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Text(translate('History Configurations')),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(Icons.close),
                                  onPressed: () {
                                    showHistory.value = false;
                                    showButtons.value = true; // 关闭历史面板时显示按钮
                                  },

                                ),
                              ],
                            ),
                          ),

                          // 添加分割线
                          const Divider(height: 1, thickness: 1),

                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return SingleChildScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: constraints.maxHeight - 50,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ...historyConfigs.asMap().entries.map((entry) {
                                          final index = entry.key + 1;
                                          final config = entry.value;

                                          return Column(
                                            children: [
                                              ListTile(
                                                contentPadding: const EdgeInsets.symmetric(
                                                    horizontal: 16, vertical: 8),
                                                // 添加序号标签
                                                leading: Container(
                                                  width: 28,
                                                  height: 28,
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context).primaryColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '$index',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                title: Text(
                                                  '${translate('ID Server')}: ${config.idServer}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                                subtitle: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${translate('Relay Server')}: ${config.relayServer}',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey[600]),
                                                    ),
                                                    Text(
                                                      '${translate('API Server')}: ${config.apiServer}',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey[600]),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                                trailing: IconButton( // 添加删除按钮
                                                  icon: Icon(Icons.delete, size: 20),
                                                  onPressed: () {
                                                    deleteHistoryConfig(index);
                                                  },
                                                ),
                                                onTap: () {
                                                  controllers[0].text = config.idServer;
                                                  controllers[1].text = config.relayServer;
                                                  controllers[2].text = config.apiServer;
                                                  controllers[3].text = config.key;
                                                  showHistory.value = false;
                                                  showButtons.value = true;
                                                },
                                              ),
                                              const Divider(
                                                height: 1,
                                                thickness: 1,
                                                indent: 16,
                                                endIndent: 16,
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }),
      actions: [

        Obx(() => showButtons.value
            ? Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              dialogButton('Cancel', onPressed: close, isOutline: true),
              SizedBox(width: 10),
              dialogButton('OK', onPressed: () async {
                final config = ServerConfig(
                    idServer: idCtrl.text.trim(),
                    relayServer: relayCtrl.text.trim(),
                    apiServer: apiCtrl.text.trim(),
                    key: keyCtrl.text.trim());

                // 保存配置并检查结果
                final success = await setServerConfig(controllers, errMsgs, config);
                if (success) {
                  close(); // 保存成功才关闭对话框
                } 
              }),
            ],
        ) : SizedBox.shrink(),
        ),
      ],
    );
  });
}


void setPrivacyModeDialog(
  OverlayDialogManager dialogManager,
  List<TToggleMenu> privacyModeList,
  RxString privacyModeState,
) async {
  dialogManager.dismissAll();
  dialogManager.show((setState, close, context) {
    return CustomAlertDialog(
      title: Text(translate('Privacy mode')),
      content: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: privacyModeList
              .map((value) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    title: value.child,
                    value: value.value,
                    onChanged: value.onChanged,
                  ))
              .toList()),
    );
  }, backDismiss: true, clickMaskDismiss: true);
}
