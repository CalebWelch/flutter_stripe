import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:stripe_platform_interface/stripe_platform_interface.dart';

/// Customizable form that collects card information.
class MyCardField extends StatefulWidget {
  const MyCardField({
    required this.onCardChanged,
    Key? key,
    this.onFocus,
    this.decoration,
    this.enablePostalCode = false,
    this.style,
    this.autofocus = false,
    this.dangerouslyGetFullCardDetails = false,
    this.cursorColor,
    this.numberHintText,
    this.expirationHintText,
    this.cvcHintText,
    this.postalCodeHintText,
  }) : super(key: key);

  /// Decoration related to the input fields.
  final InputDecoration? decoration;

  /// Callback that will be executed when a specific field gets focus.
  final CardFocusCallback? onFocus;

  /// Callback that will be executed when the card information changes.
  final CardChangedCallback onCardChanged;

  /// Textstyle of the card input fields.
  final TextStyle? style;

  /// Color of the cursor when a field gets focus.
  final Color? cursorColor;

  /// Whether or not to show the postalcode field in the form.
  /// Defaults is `false`.
  final bool enablePostalCode;

  /// Hint text for the card number field.
  final String? numberHintText;

  /// Hint text for the expiration date field.
  final String? expirationHintText;

  /// Hint text for the cvc field.
  final String? cvcHintText;

  /// Hint text for the postal code field.
  final String? postalCodeHintText;

  /// Defines whether or not to automatically focus on the cardfield/
  /// Default is `false`.
  final bool autofocus;

  /// Controller that can be use to execute several operations on the cardfield
  /// e.g (clear).

  /// When true the Full card details will be returned.
  ///
  /// WARNING!!! Only do this if you're certain that you fulfill the necessary
  /// PCI compliance requirements. Make sure that you're not mistakenly logging
  /// or storing full card details! See the docs for
  /// details: https://stripe.com/docs/security/guide#validating-pci-compliance
  /// Default is `false`.
  final bool dangerouslyGetFullCardDetails;

  @override
  _MyCardFieldState createState() => _MyCardFieldState();
}

class _MyCardFieldState extends State<MyCardField> {
  final FocusNode _node =
      FocusNode(debugLabel: 'CardField', descendantsAreFocusable: false);

  @override
  void initState() {
    _node.addListener(updateState);
    super.initState();
  }

  @override
  void dispose() {
    _node
      ..removeListener(updateState)
      ..dispose();

    super.dispose();
  }

  void updateState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = effectiveDecoration(widget.decoration);
    final style = effectiveCardStyle(inputDecoration);

    // Arbitrary values compared for both Android and iOS platform
    // For adding a framework input decorator, the platform one is removed
    // together with the extra padding
    final platformCardHeight = style.fontSize! + 31;
    const platformMargin = EdgeInsets.fromLTRB(12, 10, 10, 12);

    final cardHeight = platformCardHeight - platformMargin.vertical;
    return InputDecorator(
      isFocused: _node.hasFocus,
      decoration: inputDecoration,
      baseStyle: widget.style,
      child: SizedBox(
        height: cardHeight,
        child: CustomSingleChildLayout(
          delegate: const _NegativeMarginLayout(margin: platformMargin),
          child: _MethodChannelCardField(
            height: platformCardHeight,
            focusNode: _node,
            style: style,
            placeholder: CardPlaceholder(
              number: 'poop',
              expiration: widget.expirationHintText,
              cvc: widget.cvcHintText,
              postalCode: widget.postalCodeHintText,
            ),
            enablePostalCode: widget.enablePostalCode,
            onCardChanged: widget.onCardChanged,
            autofocus: widget.autofocus,
            onFocus: widget.onFocus,
          ),
        ),
      ),
    );
  }

  InputDecoration effectiveDecoration(InputDecoration? decoration) {
    final theme = Theme.of(context).inputDecorationTheme;
    final cardDecoration = decoration ?? const InputDecoration();
    return cardDecoration.applyDefaults(theme);
  }

  CardStyle effectiveCardStyle(InputDecoration decoration) {
    final fontSize = widget.style?.fontSize ??
        Theme.of(context).textTheme.subtitle1?.fontSize ??
        kCardFieldDefaultFontSize;

    final fontFamily = widget.style?.fontFamily ??
        Theme.of(context).textTheme.subtitle1?.fontFamily ??
        kCardFieldDefaultFontFamily;

    return CardStyle(
      textColor: widget.style?.color,
      fontSize: fontSize,
      fontFamily: fontFamily,
      cursorColor: widget.cursorColor,
      textErrorColor: decoration.errorStyle?.color,
      placeholderColor: decoration.hintStyle?.color,
    );
  }
}

// Crops a view by a given negative margin values.
// http://ln.hixie.ch/?start=1515099369&count=1
class _NegativeMarginLayout extends SingleChildLayoutDelegate {
  const _NegativeMarginLayout({required this.margin});

  final EdgeInsets margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final biggest = super.getConstraintsForChild(constraints).biggest;
    return BoxConstraints.expand(
      width: biggest.width + margin.horizontal,
      height: biggest.height + margin.vertical,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return super.getPositionForChild(size, childSize) - margin.topLeft;
  }

  @override
  bool shouldRelayout(covariant _NegativeMarginLayout oldDelegate) {
    return margin != oldDelegate.margin;
  }
}

class _MethodChannelCardField extends StatefulWidget {
  _MethodChannelCardField({
    required this.onCardChanged,
    Key? key,
    this.onFocus,
    this.style,
    this.placeholder,
    this.enablePostalCode = false,
    double? width,
    double? height = kCardFieldDefaultHeight,
    BoxConstraints? constraints,
    this.focusNode,
    this.autofocus = false,
  })  : assert(constraints == null || constraints.debugAssertIsValid()),
        constraints = (width != null || height != null)
            ? constraints?.tighten(width: width, height: height) ??
                BoxConstraints.tightFor(width: width, height: height)
            : constraints,
        super(key: key);

  final BoxConstraints? constraints;
  final CardFocusCallback? onFocus;
  final CardChangedCallback onCardChanged;
  final CardStyle? style;
  final CardPlaceholder? placeholder;
  final bool enablePostalCode;
  final FocusNode? focusNode;
  final bool autofocus;

  // This is used in the platform side to register the view.
  static const _viewType = 'flutter.stripe/card_field';

  // By platform level limitations only one CardField is allowed at the same
  // time.
  // A unique key is used to throw an expection before multiple platform
  // views are created
  static late final _key = UniqueKey();

  @override
  _MethodChannelCardFieldState createState() => _MethodChannelCardFieldState();
}

class _MethodChannelCardFieldState extends State<_MethodChannelCardField> {
  MethodChannel? _methodChannel;

  final _focusNode =
      FocusNode(debugLabel: 'CardField', descendantsAreFocusable: false);
  FocusNode get _effectiveNode => widget.focusNode ?? _focusNode;

  CardStyle? _lastStyle;
  CardStyle resolveStyle(CardStyle? style) {
    final theme = Theme.of(context);
    final baseTextStyle = Theme.of(context).textTheme.subtitle1;
    return CardStyle(
      borderWidth: 10,
      backgroundColor: Colors.orange,
      borderColor: Colors.black,
      borderRadius: 10,
      cursorColor: theme.textSelectionTheme.cursorColor ?? theme.primaryColor,
      textColor: style?.textColor ??
          baseTextStyle?.color ??
          kCardFieldDefaultTextColor,
      fontSize: baseTextStyle?.fontSize ?? kCardFieldDefaultFontSize,
      fontFamily: baseTextStyle?.fontFamily ?? kCardFieldDefaultFontFamily,
      textErrorColor:
          theme.inputDecorationTheme.errorStyle?.color ?? theme.errorColor,
      placeholderColor:
          theme.inputDecorationTheme.hintStyle?.color ?? theme.hintColor,
    ).apply(style);
  }

  CardPlaceholder? _lastPlaceholder;
  CardPlaceholder resolvePlaceholder(CardPlaceholder? placeholder) =>
      CardPlaceholder(
        number: '1234123412341234',
        expiration: 'MM/YY',
        cvc: 'CVC',
      ).apply(placeholder);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = resolveStyle(widget.style);
    final placeholder = resolvePlaceholder(widget.placeholder);
    // Pass parameters to the platform side.
    final creationParams = <String, dynamic>{
      'cardStyle': style.toJson(),
      'placeholder': placeholder.toJson(),
      'postalCodeEnabled': widget.enablePostalCode,
    };

    Widget platform;
    if (defaultTargetPlatform == TargetPlatform.android) {
      platform = _AndroidCardField(
        key: _MethodChannelCardField._key,
        viewType: _MethodChannelCardField._viewType,
        creationParams: creationParams,
        onPlatformViewCreated: onPlatformViewCreated,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      platform = _UiKitCardField(
        key: _MethodChannelCardField._key,
        viewType: _MethodChannelCardField._viewType,
        creationParams: creationParams,
        onPlatformViewCreated: onPlatformViewCreated,
      );
    } else {
      throw UnsupportedError('Unsupported platform view');
    }
    final constraints = widget.constraints ??
        const BoxConstraints.expand(height: kCardFieldDefaultHeight);

    return Listener(
      onPointerDown: (_) {
        if (!_effectiveNode.hasFocus) {
          _effectiveNode.requestFocus();
        }
      },
      child: Focus(
        autofocus: true,
        descendantsAreFocusable: false,
        focusNode: _effectiveNode,
        onFocusChange: _handleFrameworkFocusChanged,
        child: ConstrainedBox(
          constraints: constraints,
          child: platform,
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    _lastStyle ??= resolveStyle(widget.style);
    final style = resolveStyle(widget.style);
    if (style != _lastStyle) {
      _methodChannel?.invokeMethod('onStyleChanged', {
        'cardStyle': style.toJson(),
      });
    }
    _lastStyle = style;
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant _MethodChannelCardField oldWidget) {
    if (widget.enablePostalCode != oldWidget.enablePostalCode) {
      _methodChannel?.invokeMethod('onPostalCodeEnabledChanged', {
        'postalCodeEnabled': widget.enablePostalCode,
      });
    }
    _lastStyle ??= resolveStyle(oldWidget.style);
    final style = resolveStyle(widget.style);
    if (style != _lastStyle) {
      _methodChannel?.invokeMethod('onStyleChanged', {
        'cardStyle': style.toJson(),
      });
    }
    _lastStyle = style;
    final placeholder = resolvePlaceholder(widget.placeholder);
    if (placeholder != _lastPlaceholder) {
      _methodChannel?.invokeMethod('onPlaceholderChanged', {
        'placeholder': placeholder.toJson(),
      });
    }
    _lastPlaceholder = placeholder;
    super.didUpdateWidget(oldWidget);
  }

  void onPlatformViewCreated(int viewId) {
    _focusNode.debugLabel = 'CardField(id: $viewId)';
    _methodChannel = MethodChannel('flutter.stripe/card_field/$viewId');
    _methodChannel?.setMethodCallHandler((call) async {
      if (call.method == 'topFocusChange') {
        _handlePlatformFocusChanged(call.arguments);
      } else if (call.method == 'onCardChange') {
        _handleCardChanged(call.arguments);
      }
    });
  }

  void _handleCardChanged(arguments) {
    try {
      final map = Map<String, dynamic>.from(arguments);
      final details = CardFieldInputDetails.fromJson(map);
      widget.onCardChanged.call(details);
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      log('An error ocurred while while parsing card arguments, this should not happen, please consider creating an issue at https://github.com/flutter-stripe/flutter_stripe/issues/new');
      rethrow;
    }
  }

  /// Handler called when a field from the platform card field has been focused
  void _handlePlatformFocusChanged(arguments) {
    try {
      final map = Map<String, dynamic>.from(arguments);
      final field = CardFieldFocusName.fromJson(map);
      if (field.focusedField != null &&
          WidgetsBinding.instance!.focusManager.primaryFocus !=
              _effectiveNode) {
        _effectiveNode.requestFocus();
      }
      widget.onFocus?.call(field.focusedField);
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      log('An error ocurred while while parsing card arguments, this should not happen, please consider creating an issue at https://github.com/flutter-stripe/flutter_stripe/issues/new');
      rethrow;
    }
  }

  /// handle event that is emitted from the editting controller and propagate it
  /// through native
  /// Handler called when the focus changes in the node attached to the platform
  /// view. This updates the correspondant platform view to keep it in sync.
  void _handleFrameworkFocusChanged(bool isFocused) {
    final methodChannel = _methodChannel;
    if (methodChannel == null) {
      return;
    }
    setState(() {});
    if (!isFocused) {
      methodChannel.invokeMethod('blur');
      return;
    }

    methodChannel.invokeMethod('focus');
  }
}

class _AndroidCardField extends StatelessWidget {
  const _AndroidCardField({
    Key? key,
    required this.viewType,
    required this.creationParams,
    required this.onPlatformViewCreated,
  }) : super(key: key);

  final String viewType;
  final Map<String, dynamic> creationParams;
  final PlatformViewCreatedCallback onPlatformViewCreated;

  @override
  Widget build(BuildContext context) {
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller
            // ignore: avoid_as
            as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (params) {
        onPlatformViewCreated(params.id);
        return PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: viewType,
          layoutDirection: Directionality.of(context),
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}

class _UiKitCardField extends StatelessWidget {
  const _UiKitCardField({
    Key? key,
    required this.viewType,
    required this.creationParams,
    required this.onPlatformViewCreated,
  }) : super(key: key);

  final String viewType;
  final Map<String, dynamic> creationParams;
  final PlatformViewCreatedCallback onPlatformViewCreated;

  @override
  Widget build(BuildContext context) {
    return UiKitView(
      viewType: viewType,
      creationParamsCodec: const StandardMessageCodec(),
      creationParams: creationParams,
      onPlatformViewCreated: onPlatformViewCreated,
    );
  }
}

const kCardFieldDefaultHeight = 48.0;
const kCardFieldDefaultFontSize = 17.0;
const kCardFieldDefaultTextColor = Colors.black;
const kCardFieldDefaultFontFamily = 'Roboto';

typedef CardChangedCallback = void Function(CardFieldInputDetails? details);
typedef CardFocusCallback = void Function(CardFieldName? focusedField);