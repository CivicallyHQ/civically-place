import { on } from 'ember-addons/ember-computed-decorators';

export default Ember.Mixin.create({
  @on('init')
  addWidgetConditions() {
    const widgetConditions = {
      'civically-place': {
        requiredProp: 'category.is_place'
      }
    }

    let customSidebarProps = this.get('customSidebarProps') || {};
    customSidebarProps['widgetConditions'] = widgetConditions;

    this.set('customSidebarProps', customSidebarProps);
  }
});
