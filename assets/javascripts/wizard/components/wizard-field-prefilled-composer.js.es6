import WizardFieldComposer from 'discourse/plugins/discourse-custom-wizard/wizard/components/wizard-field-composer';
import { on } from 'ember-addons/ember-computed-decorators';

export default WizardFieldComposer.extend({
  layoutName: 'components/wizard-field-composer',
  showPreview: true,
  hasCustomCheck: true,

  // handle validation on server for now
  @on('didInsertElement')
  setup() {
    const field = this.get('field');
    field.setValid(true, null);
  }
});
