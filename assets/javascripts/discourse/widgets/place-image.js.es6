import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';

export default createWidget('place-image', {
  tagName: 'span.place-image',

  html(attrs) {
    const category = attrs.category;

    if (category.place_type === 'country' || category.place_type === 'international') {
      return h('img', {
        attributes: {
          src: category.location.flag
        }
      });
    } else {
      let emoji = category.place_type === 'town' ? 'cityscape' : 'house_with_garden';
      return this.attach('emoji', { name: emoji });
    }
  }
});
