import Category from 'discourse/models/category';
import { updateAppData } from 'discourse/plugins/civically-app/discourse/lib/app-utilities';
import { ajax } from 'discourse/lib/ajax';

let placeLabel = function(id, opts = {}) {
  const category = Category.findById(id);
  if (!category) return;

  let label = category.name;

  const parent = Category.findById(category.parent_category_id);
  if (parent && !opts.noParents) {
    label += `, ${parent.name}`;
  }

  if (opts.link) {
    label = `<a href=${category.get('url')}>${label}</a>`;
  }

  return label;
};

let countryLabel = function(id) {
  const category = Category.findById(id);
  if (!category) return;
  const parent = Category.findById(category.parent_category_id);
  if (!parent) return;

  let label = '';

  if (parent.location && parent.location.flag) {
    label += `<span class="place-image"><img src=${parent.location.flag}></span>`;
  }

  label += `<span>${parent.name}</span>`;

  return label;
};

let placeTime = function(time) {
  return time ? moment(time).format('MMMM Do') : null;
};

let formatNum = function(num) {
  if (num) {
    return num.toLocaleString('en-US');
  } else {
    return 0;
  }
};

let placeUrl = function(user) {
  if (!user) return "/start#banner";

  if (user.town_category_id) {
    const home = user.place_home;
    let categoryId;

    if (home ==='country') {
      categoryId = user.town.parent_category_id;
    } else {
      categoryId = user[`${home}_category_id`];
    }

    const category = Category.findById(categoryId);

    if (category) {
      const url = category.get('url');
      return url;
    }
  }

  return '/place/set';
};

let categoryLabel = function(category) {
  if (!category) return '';
  let contents = `${category.name}`;
  return `<span class="category">${contents}</span>`;
};

let setPlace = function(category_id, type, user_id = null) {
  let data = {
    category_id,
    type
  };

  if (user_id) data['user_id'] = user_id;

  return ajax('/place/user/set', { type: 'PUT', data });
};

let resolvePlaceSet = function(result) {
  if (result.message || result.error) {
    bootbox.alert(result.message || result.error);
    return false;
  }

  const user = Discourse.User.current();
  let userProps = {};

  if (result.town_category_id) {
    let categoryId = Number(result.town_category_id);
    userProps['town_category_id'] = categoryId;
  }

  if (result.town) {
    userProps['town'] = result.town;
  }

  if (result.town_joined_at) {
    userProps['town_joined_at'] = result.town_joined_at;
  }

  user.setProperties(userProps);

  if (result.app_data) {
    let appData = result.app_data;

    Object.keys(appData).forEach(appName => {
      updateAppData(user, appName, appData[appName]);
    });
  }

  return true;
};

export {
  placeUrl,
  placeLabel,
  countryLabel,
  placeTime,
  formatNum,
  categoryLabel,
  setPlace,
  resolvePlaceSet
};
