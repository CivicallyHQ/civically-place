import { clearUnreadList } from 'discourse/plugins/civically-layout/discourse/lib/utilities';
import { createWidget } from 'discourse/widgets/widget';
import { ajax } from 'discourse/lib/ajax';
import { h } from 'virtual-dom';

export default createWidget('place-list', {
  tagName: 'div.widget-list',
  buildKey: (attrs) => `${attrs.type}-event-list`,

  defaultState() {
    return {
      items: [],
      loading: true
    };
  },

  getItems(category, type) {
    if (!category) {
      this.state.loading = false;
      this.scheduleRerender();
      return;
    }

    ajax(`/place/${type}s`, {
      data: {
        category_id: category.id
      }
    }).then((items) => {
      this.state.items = items;
      this.state.loading = false;
      this.scheduleRerender();
    });
  },

  html(attrs, state) {
    const items = state.items;
    const loading = state.loading;
    const category = attrs.category;
    const type = attrs.type;
    const currentPlace = attrs.currentPlace;
    const member = currentPlace.member;
    const moderators = currentPlace.category.moderators;
    const moderator = moderators && moderators.length > 2;

    let contents = [];

    if (loading) {
      this.getItems(category, type);
      contents.push(h('div.spinner.small'));
    } else {
      let listContents = h('div.no-items', I18n.t('place.list.none', { type, place: category.name }));

      if (items && items.length > 0) {
        listContents = items.map((item) => {
          return this.attach(`place-list-item`, {
            item,
            type
          });
        });
      };

      clearUnreadList(this, type);

      contents.push(h('ul', listContents));
    }

    contents.push(this.attach('place-list-controls', {
      category,
      currentPlace,
      member,
      moderator,
      type,
    }));

    return contents;
  }
});
