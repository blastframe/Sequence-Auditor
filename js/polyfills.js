/*
 * polyfills.js
 * Minimal ES3 polyfills used by the exporter & zip
 */

if (!Array.isArray) {
  Array.isArray = function (arg) {
    return Object.prototype.toString.call(arg) === "[object Array]";
  };
}
if (!Array.prototype.some) {
  Array.prototype.some = function (cb) {
    for (var i = 0; i < this.length; i++) {
      if (cb(this[i], i, this)) return true;
    }
    return false;
  };
}
if (!Array.prototype.indexOf) {
  Array.prototype.indexOf = (function (Object, max, min) {
    "use strict";
    return function (member, fromIndex) {
      if (this === null || this === undefined)
        throw TypeError("Array.prototype.indexOf called on null/undefined");
      var that = Object(this),
        Len = that.length >>> 0,
        i = min(fromIndex | 0, Len);
      if (i < 0) i = max(0, Len + i);
      else if (i >= Len) return -1;
      if (member === void 0) {
        for (; i !== Len; ++i) if (that[i] === void 0 && i in that) return i;
      } else if (member !== member) {
        for (; i !== Len; ++i) if (that[i] !== that[i]) return i;
      } else for (; i !== Len; ++i) if (that[i] === member) return i;
      return -1;
    };
  })(Object, Math.max, Math.min);
}
if (!Array.prototype.includes) {
  Array.prototype.includes = function (search) {
    return !!~this.indexOf(search);
  };
}
if (!String.prototype.endsWith) {
  String.prototype.endsWith = function (searchString, position) {
    var subjectString = this.toString();
    if (
      typeof position !== "number" ||
      !isFinite(position) ||
      Math.floor(position) !== position ||
      position > subjectString.length
    ) {
      position = subjectString.length;
    }
    position -= searchString.length;
    var lastIndex = subjectString.indexOf(searchString, position);
    return lastIndex !== -1 && lastIndex === position;
  };
}
if (!String.prototype.startsWith) {
  String.prototype.startsWith = function (prefix) {
    return this.indexOf(prefix) === 0;
  };
}
if (!Array.prototype.reduce) {
  Array.prototype.reduce = function (callback, initialValue) {
    if (this === null || this === undefined)
      throw new TypeError("Array.prototype.reduce called on null/undefined");
    if (typeof callback !== "function")
      throw new TypeError(callback + " is not a function");
    var list = Object(this),
      length = list.length >>> 0,
      acc = initialValue,
      index = 0;
    if (arguments.length < 2) {
      if (length === 0)
        throw new TypeError("Reduce of empty array with no initial value");
      acc = list[index++];
    }
    while (index < length) {
      acc = callback.call(undefined, acc, list[index], index, list);
      index++;
    }
    return acc;
  };
}
if (!Array.prototype.map) {
  Array.prototype.map = function (callback, thisArg) {
    if (this == null) throw new TypeError(" this is null or not defined");
    var O = Object(this),
      len = O.length >>> 0;
    if (typeof callback !== "function")
      throw new TypeError(callback + " is not a function");
    var A = new Array(len),
      T = arguments.length > 1 ? thisArg : undefined,
      k = 0;
    while (k < len) {
      if (k in O) {
        A[k] = callback.call(T, O[k], k, O);
      }
      k++;
    }
    return A;
  };
}
