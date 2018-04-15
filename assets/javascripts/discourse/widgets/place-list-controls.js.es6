import { createWidget } from 'discourse/widgets/widget';
import { getOwner } from 'discourse-common/lib/get-owner';

const HAS_CREATE = ['event', 'group', 'rating'];

const CREATE_PERMISSIONS = {
  event: ['moderator', 'member'],
  group: ['moderator', 'member'],
  rating: ['moderator', 'member']
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
        className: 'pull-right p-link'
      }));
    }

    return links;
  },

  create() {
    const attrs = this.attrs;
    const listType = attrs.listType;
    const category = attrs.category;
    const permissions = CREATE_PERMISSIONS[listType];
    let notPermitted = [];

    permissions.forEach((p) => {
      if (!attrs[p]) notPermitted.push(p);
    });

    if (notPermitted.length > 0) {
      let message = `${I18n.t('place.list.not_permitted.intro')}<br>`;
      message += `<ul class='list-not-permitted'>`;
      notPermitted.forEach((key) => {
        message += '<li>';
        message += I18n.t(`place.list.not_permitted.${key}`, {
          place: category.place_name
        });
        if (key === 'moderator' && category.moderator_election_url) {
          message += ` <a href='${category.moderator_election_url}' class='p-link' target='_blank'>
                      ${I18n.t('place.list.not_permitted.moderator_link')}</a>`;
        }
        message += '</li>';
      });
      message += '</ul>';
      return bootbox.alert(message);
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
        sublistType: listType
      }
    };

    if (category) {
      params['categoryId'] = category.id;
    }

    controller.open(params);
  }
});
