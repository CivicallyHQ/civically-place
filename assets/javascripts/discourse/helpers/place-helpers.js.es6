import { registerUnbound } from 'discourse-common/lib/helpers';
import { placeLabel, placeTime, formatNum, countryLabel, topicPlaceLabel } from '../lib/place-utilities';

registerUnbound('country-label', function(categoryId, opts) {
  return new Handlebars.SafeString(countryLabel(categoryId, opts));
});

registerUnbound('topic-place-label', function(category, opts) {
  let topic = opts && opts.topic ? opts.topic : null;
  return new Handlebars.SafeString(topicPlaceLabel(category, topic));
});

registerUnbound('place-label', function(categoryId, opts) {
  return new Handlebars.SafeString(placeLabel(categoryId, opts));
});

registerUnbound('place-time', function(time) {
  return new Handlebars.SafeString(placeTime(time));
});

registerUnbound('format-number', function(num) {
  return new Handlebars.SafeString(formatNum(num));
});
