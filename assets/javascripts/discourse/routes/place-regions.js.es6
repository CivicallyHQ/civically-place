import { ajax } from 'discourse/lib/ajax';

export default Ember.Route.extend({
  model(params) {
    if (params.category_id) {
      this.set('categoryId', params.category_id);
    }
    return [];
  },

  setupController(controller, model) {
    const categoryId = this.get('categoryId');
    if (categoryId) {
      controller.set('categoryId', categoryId);
    }
  }
});
