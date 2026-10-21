import 'dart:js_interop';

/// `gtag` from web/index.html: only defined on the production site with a measurement ID set.
@JS('gtag')
external JSFunction? get _gtag;

/// Reports [location] (`/readings/12`) as a page view. The app's URLs are `#/readings/12`, and
/// Analytics drops the fragment, so the page is sent as a path of the site.
void trackPageView(String location) {
  _gtag?.callAsFunction(null, 'event'.toJS, 'page_view'.toJS, {'page_location': '${Uri.base.origin}$location'}.jsify());
}
