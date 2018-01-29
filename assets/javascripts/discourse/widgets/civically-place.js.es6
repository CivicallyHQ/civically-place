import { createWidget } from 'discourse/widgets/widget';
import Place from '../models/place';
import { h } from 'virtual-dom';

export default createWidget('civically-place', {
  tagName: 'div',
  buildKey: () => 'civically-place',

  defaultState() {
    return {
      currentType: 'event',
      place: null
    };
  },

  buildClasses() {
    let classes = 'civically-place widget-container';

    const category = this.attrs.category;
    if (!category || !category.place) {
      classes += ' hidden';
    }
    return classes;
  },

  buildTitle(type) {
    const currentType = this.state.currentType;
    const active = currentType === type;

    let classes = 'list-title';
    if (active) classes += ' active';

    let attrs = {
      action: 'showList',
      actionParam: type,
      title: `place.${type}.help`,
      label: `place.${type}.title`,
      className: classes
    };

    return this.attach('link', attrs);
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

  html(attrs, state) {
    const category = this.attrs.category;
    if (!category || !category.place) return;

    let contents = [];

    if (!state.place || state.place.category_id !== category.id) {
      contents.push(h('div.spinner.small'));
      this.createPlace(category.id);
    } else {
      contents.push(
        h('div.widget-label', category.name),
        h('div.widget-multi-title', [
          this.buildTitle('event'),
          this.buildTitle('group'),
          this.buildTitle('rating'),
          this.buildTitle('petition')
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
