import { setPlace } from 'discourse/plugins/civically-place/discourse/lib/place-utilities';
import { on } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: ['admin-user-select'],

  @on('init')
  initSelectedId() {
    const townCategoryId = this.get('model.town_category_id');
    if (townCategoryId) {
      this.set('selectedId', townCategoryId);
    }
  },

  actions: {
    setPlace(selectedId) {
      const townCategoryId = this.get('model.town_category_id');
      const userId = this.get('model.id');

      if (!selectedId || selectedId === townCategoryId) return;

      this.set('loading', true);

      setPlace(selectedId, 'town', userId).then((result) => {
        this.set('loading', false);

        if (result.error) {
          return bootbox.alert(result.error);
        }

        this.set('model.town_category_id', Number(selectedId));
      });
    }
  }
});
