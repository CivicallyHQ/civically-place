import Place from '../models/place';

export default Ember.Route.extend({
  model() {
    const user = this.get('currentUser');
    if (user && user.place_category_id) {
      return Place.create({ category_id: user.place_category_id });
    } else {
      return null;
    }
  }
});
