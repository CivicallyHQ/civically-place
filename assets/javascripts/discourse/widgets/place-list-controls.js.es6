import { createWidget } from 'discourse/widgets/widget';
import { getOwner } from 'discourse-common/lib/get-owner';

const HAS_CREATE = ['event', 'group', 'rating'];

const CREATE_PERMISSIONS = {
  event: { member: true, trust: { level: 3, key: 'regular' }},
  group: { member: true, trust: { level: 3, key: 'regular' }},
  rating: { member: true, trust: { level: 2, key: 'member' }}
};

const CREATE_URL = {
  group: '/w/group-petition'
};

const listTypeUrl = function(listType, category) {
  let url = '/c/';

  if (category.parentCategory) {
    url += `${category.parentCategory.slug}/`;
  };

  url += category.slug;

  let filter = '';

  switch(listType) {
    case 'petition':
      filter = `${url}/l/petitions`;
      break;
    case 'group':
      filter = `/groups?category_id=${category.id}`;
      break;
    case 'rating':
      filter = `${url}/l/ratings`;
      break;
    case 'event':
      filter = `${url}/l/calendar`;
      break;
  };

  return filter;
};

export default createWidget('place-list-controls', {
  tagName: 'div.widget-list-controls',

  html(attrs) {
    const listType = attrs.listType;
    const user = this.currentUser;
    const category = attrs.category;
    const moreLink = listTypeUrl(listType, category);

    let links = [this.attach('link', {
      className: 'p-link',
      href: moreLink,
      label: 'more'
    })];

    if (user && HAS_CREATE.indexOf(listType) > -1) {
      links.push(this.attach('link', {
        label: `place.${listType}.create`,
        action: 'create',
        className: 'right p-link'
      }));
    }

    return links;
  },

  create() {
    const attrs = this.attrs;
    const listType = attrs.listType;
    const category = attrs.category;
    const user = this.currentUser;
    const permissions = CREATE_PERMISSIONS[listType];
    let notPermitted = [];

    Object.keys(permissions).forEach((k) => {
      let messages = [];
      let permission = permissions[k];

      if (k === 'member' && permission && user.place_category_id !== category.id) {
        messages.push(I18n.t('place.list.not_permitted.member', {
          place: category.place_name
        }));
      }

      if (k === 'trust' && Number(user.trust_level) < Number(permission.level)) {
        messages.push(I18n.t('place.list.not_permitted.trust', {
          level: permission.level,
          label: I18n.t(`badges.${permission.key}.name`)
        }));
      }

      if (messages.length > 0) notPermitted.push(...messages);
    });

    if (notPermitted.length > 0) {
      let body = `${I18n.t('place.list.not_permitted.intro')}<br><ul class='list-not-permitted'>`;

      notPermitted.forEach((message) => {
        body += '<li>';
        body += message;
        body += '</li>';
      });

      body += '</ul>';

      return bootbox.alert(body);
    }

    if (CREATE_URL[listType]) {
      return window.location.href = CREATE_URL[listType];
    }

    const controller = getOwner(this).lookup('controller:composer');

    let params = {
      action: 'createTopic',
      draftKey: 'new_topic',
      draftSequence: 0,
      addProperties: {
        subtype: listType
      }
    };

    if (category) {
      params['categoryId'] = category.id;
    }

    controller.open(params);
  }
});
