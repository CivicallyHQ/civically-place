import { h } from 'virtual-dom';

// Place Widget
const navigationUtilitiesPath = 'discourse/plugins/civically-navigation/discourse/lib/utilities';
const appWidgetPath = 'discourse/plugins/civically-app/discourse/widgets/app-widget';
let placeWidget = {};

if (requirejs.entries[navigationUtilitiesPath] && requirejs.entries[appWidgetPath]) {
  const buildTitle = requirejs(navigationUtilitiesPath).buildTitle;
  const createAppWidget = requirejs(appWidgetPath).createAppWidget;

  const placeWidgetParams = {
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
      const { category } = this.attrs;
      const user = this.currentUser;

      if (!category || !category.is_place) return;

      const userPlace = user.get('place');
      const listType = this.state.currentListType;
      let contents = [];

      let image;

      if (category.place_type === 'country') {
        image = h('img', { attributes: { src: category.location.flag }});
      } else {
        let emoji = category.place_type === 'town' ? 'cityscape' : 'house_with_garden';
        image = this.attach('emoji', { name: emoji });
      }

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
  };

  placeWidget = createAppWidget('civically-place', placeWidgetParams);
}

export default placeWidget;
