import { default as computed } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: ['place-select'],

  actions: {
    setPlace() {
      this.sendAction('setPlace', this.get('selectedId'));
    }
  }
});
