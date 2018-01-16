import { registerUnbound } from 'discourse-common/lib/helpers';
import { placeLabel, placeTime, formatNum } from '../lib/place-utilities';

registerUnbound('place-label', function(categoryId, opts) {
  return new Handlebars.SafeString(placeLabel(categoryId, opts));
});

registerUnbound('place-time', function(time) {
  return new Handlebars.SafeString(placeTime(time));
});

registerUnbound('format-number', function(num) {
  return new Handlebars.SafeString(formatNum(num));
});
