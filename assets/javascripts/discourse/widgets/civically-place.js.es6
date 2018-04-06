import { createAppWidget } from 'discourse/plugins/civically-app/discourse/widgets/app-widget';
import Place from '../models/place';
import { h } from 'virtual-dom';
import { buildTitle } from 'discourse/plugins/civically-layout/discourse/lib/utilities';

export default createAppWidget('civically-place', {
  defaultState() {
    return {
      currentType: 'event',
      place: null
    };
  },

  showList(currentType) {
    this.state.currentType = currentType;
    this.scheduleRerender();
  },

  createPlace(categoryId) {
    Place.create({ category_id: categoryId }).then((result) => {
      this.state.place = result;
      this.scheduleRerender();
    });
  },

  contents(attrs, state) {
    const category = attrs.category;
    if (!category || !category.place) return;

    let contents = [];

    if (!state.place || state.place.category_id !== category.id) {
      contents.push(h('div.spinner.small'));
      this.createPlace(category.id);
    } else {
      contents.push(
        h('div.app-title', category.name),
        h('div.widget-multi-title', [
          buildTitle(this, 'place', 'event'),
          buildTitle(this, 'place', 'group'),
          buildTitle(this, 'place', 'rating'),
          buildTitle(this, 'place', 'petition')
        ])
      );

      let listAttrs = {
        category,
        type: state.currentType,
        currentPlace: state.place,
        userPlace: this.attrs.userPlace
      };

      contents.push(this.attach(`place-list`, listAttrs));

      if (attrs.editing) {
        contents.push(this.attach('app-edit', {
          side: attrs.side,
          index: attrs.index,
          name: 'civically-place',
          noRemove: true
        }));
      }
    };

    return contents;
  }
});
