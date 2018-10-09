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

let topicPlaceLink = function(category) {
  let icon;

  switch(category.place_type) {
    case 'country':
      icon = 'globe';
      break;
    case 'town':
      icon = 'building';
      break;
    case 'neighbourhood':
      icon = 'home';
      break;
  }

  return `<i class="fa fa-${icon}"></i><a href=${category.get('url')} class="topic-place-link p-link">${category.get('name')}</a>`;
}

let regionLabel = function(name) {
  return `<span class="region-label">${name}</span>`;
}

let regionsLabel = function(regions) {
  let contents = '<i class="fa fa-map"></i>';
  if (regions.length > 1) {
    regions.forEach((r, i) => {
      contents += regionLabel(r.name);
      if (i < (regions.length - 1)) {
        contents += ', ';
      }
    });
  } else {
    contents += regionLabel(regions[0].name);
  }
  return `<span class="regions-label">${contents}</span>`;
}

let topicPlaceLabel = function(topic) {
  const category = topic.get('category');
  const parent = category.get('parentCategory');
  const grandparent = category.get('parentCategory.parentCategory');
  const regions = topic.get('regions');
  let grandparentRegions = [];
  let parentRegions = [];
  let categoryRegions = [];

  if (regions.length) {
    if (grandparent) grandparentRegions = regions.filter(r => r.category_id === grandparent.id);
    if (parent) parentRegions = regions.filter(r => r.category_id === parent.id);
    categoryRegions = regions.filter(r => r.category_id === category.id);
  }

  let label = '';

  /*
  if (grandparent) {
    label += topicPlaceLink(grandparent);
  }

  if (regions.length && grandparentRegions.length) {
    label += `${regionsLabel(grandparentRegions)}`;
  }

  if (parent) {
    label += topicPlaceLink(parent);
  }
  */

  if (regions.length) {
    if (categoryRegions.length) {
      label = regionsLabel(categoryRegions);
    } else if (parentRegions.length) {
      label = regionsLabel(parentRegions);
    } else if (grandparentRegions.length) {
      label = regionsLabel(grandparentRegions);
    }
  } else {
    label = topicPlaceLink(category);
  }

  return `<div class="topic-place-label">${label}</div>`;
}

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

const getRegions = function(category) {
  let regions = [];

  if (category.regions) {
    regions.push(...category.regions);
  }

  if (category.place_type === 'town' || category.place_type === 'neighbourhood') {
    regions.push(...category.get('parentCategory.regions'));
  }

  if (category.place_type === 'neighbourhood') {
    regions.push(...category.get('parentCategory.parentCategory.regions'));
  }

  return regions;
};

export {
  placeUrl,
  placeLabel,
  countryLabel,
  placeTime,
  formatNum,
  categoryLabel,
  topicPlaceLabel,
  setPlace,
  resolvePlaceSet,
  getRegions
};
