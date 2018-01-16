import { observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Mixin.create({
  userPlace: Ember.computed.alias('application.userPlace'),

  @observes('userPlace')
  addUserPlaceToCustomProps() {
    const userPlace = this.get('userPlace');
    if (userPlace) {
      let customProps = this.get('customProps') || [];
      customProps.push({ userPlace });
      this.set('customProps', customProps);
    }
  }
});
