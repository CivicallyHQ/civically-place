import Category from 'discourse/models/category';
import { on } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: ['admin-user-select'],

  @on('init')
  initSelectedId() {
    const placeCategoryId = this.get('model.place_category_id');
    if (placeCategoryId) {
      this.set('selectedId', placeCategoryId);
    }
  },



  actions: {
    setPlace(selectedId) {
      const placeCategoryId = this.get('model.place_category_id');
      const userId = this.get('model.id');

      if (!selectedId || selectedId === placeCategoryId) return;

      this.set('loading', true);
      Category.setPlace(selectedId, userId).then((result) => {
        this.set('loading', false);
        if (result.error) {
          return bootbox.alert(result.error);
        }
        this.set('model.place_category_id', Number(selectedId));
      });
    }
  }
});
