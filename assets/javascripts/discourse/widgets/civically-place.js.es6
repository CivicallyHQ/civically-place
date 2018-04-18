import { createAppWidget } from 'discourse/plugins/civically-app/discourse/widgets/app-widget';
import { h } from 'virtual-dom';
import { buildTitle } from 'discourse/plugins/civically-navigation/discourse/lib/utilities';

export default createAppWidget('civically-place', {
  defaultState() {
    return {
      currentListType: 'event'
    };
  },

  showList(currentListType) {
    this.state.currentListType = currentListType;
    this.scheduleRerender();
  },

  contents() {
    const { category, editing } = this.attrs;
    const user = this.currentUser;

    if (!category || !category.is_place) return;

    const userPlace = user.get('place');
    const listType = this.state.currentListType;
    let contents = [];

    let image = category.place_type === 'country' ?
                h('img', { attributes: { src: category.location.flag }}) :
                this.attach('emoji', { name: 'house_buildings' });

    contents.push(
      h('div.app-widget-header', [
        h('span', image),
        h('span.app-widget-title', category.place_name)
      ]),
      h('div.widget-multi-title', [
        buildTitle(this, 'place', 'event'),
        buildTitle(this, 'place', 'group'),
        buildTitle(this, 'place', 'rating'),
        buildTitle(this, 'place', 'petition')
      ])
    );

    let listAttrs = {
      category,
      listType,
      userPlace
    };

    contents.push(this.attach(`place-list`, listAttrs));

    return contents;
  }
});
