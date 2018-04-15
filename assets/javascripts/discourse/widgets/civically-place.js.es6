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
    const state = this.state;

    if (!category || !category.is_place) return;

    const userPlace = user.get('place');
    const listType = state.currentListType;
    let contents = [];

    contents.push(
      h('div.app-title', category.place_name),
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
