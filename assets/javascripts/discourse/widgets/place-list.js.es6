import { createWidget } from 'discourse/widgets/widget';
import { ajax } from 'discourse/lib/ajax';
import { h } from 'virtual-dom';

const navigationUtilitiesPath = 'discourse/plugins/civically-navigation/discourse/lib/utilities';
let placeListWidget = {};

if (requirejs.entries[navigationUtilitiesPath]) {
  const clearUnreadList = requirejs(navigationUtilitiesPath).clearUnreadList;

  const placeListWidgetParams = {
    tagName: 'div.widget-list',
    buildKey: (attrs) => `${attrs.listType}-event-list`,

    defaultState() {
      return {
        items: [],
        loading: true
      };
    },

    getItems(category, listType) {
      if (!category) {
        this.state.loading = false;
        this.scheduleRerender();
        return;
      }

      ajax(`/place/${listType}s`, {
        data: {
          category_id: category.id
        }
      }).then((result) => {
        if (result.topic_list) {
          this.state.items = result.topic_list.topics;
        } else {
          this.state.items = result;
        }
        this.state.loading = false;
        this.scheduleRerender();
      });
    },

    html(attrs, state) {
      const items = state.items;
      const loading = state.loading;
      const category = attrs.category;
      const listType = attrs.listType;

      const moderators = category.moderators;
      const moderator = moderators && moderators.length > 2;

      let contents = [];

      if (loading) {
        this.getItems(category, listType);
        contents.push(h('div.spinner.small'));
      } else {
        let listTypeTitle = I18n.t(`place.${listType}.title`);
        let listContents = h('div.no-items', I18n.t('place.list.none', {
          listType: listTypeTitle,
          place: category.place_name
        }));

        if (items && items.length > 0) {
          listContents = items.map((item) => {
            return this.attach(`place-list-item`, {
              item,
              listType
            });
          });
        };

        clearUnreadList(this, listType);

        contents.push(h('ul', listContents));
      }

      contents.push(this.attach('place-list-controls', {
        category,
        moderator,
        listType,
      }));

      return contents;
    }
  };

  placeListWidget = createWidget('place-list', placeListWidgetParams);
}

export default placeListWidget;
