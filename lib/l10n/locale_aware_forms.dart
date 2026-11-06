import 'package:flutter/widgets.dart';

/// Revalidate only fields already showing an error when the display locale changes.
/// Controllers, focus, routes and unedited fields retain their existing state.
class LocaleAwareForms extends StatefulWidget {
  const LocaleAwareForms({super.key, required this.child});
  final Widget child;
  @override
  State<LocaleAwareForms> createState() => _LocaleAwareFormsState();
}

class _LocaleAwareFormsState extends State<LocaleAwareForms> {
  Locale? _locale;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Localizations.maybeLocaleOf(context);
    if (_locale != null && next != _locale) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        void visit(Element element) {
          if (element is StatefulElement && element.state is FormFieldState) {
            final field = element.state as FormFieldState;
            if (field.hasError) field.validate();
          }
          element.visitChildElements(visit);
        }

        context.visitChildElements(visit);
      });
    }
    _locale = next;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
