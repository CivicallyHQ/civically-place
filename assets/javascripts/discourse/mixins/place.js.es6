import { observes, on } from 'ember-addons/ember-computed-decorators';

export default Ember.Mixin.create({
  @on('init')
  addWidgetConditions() {
    const widgetConditions = {
      'civically-place': {
        requiredProp: 'category.is_place'
      }
    }

    let customWidgetProps = this.get('customWidgetProps') || [];
    customWidgetProps.push({ widgetConditions });

    this.set('customWidgetProps', customWidgetProps);
  }
});
