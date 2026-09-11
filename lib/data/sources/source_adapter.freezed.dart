// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_adapter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ParsedArticle {

 String get guid; String get title; String get link; DateTime get publishedAt; String? get summary; String? get contentSnippet; String? get fullContentHtml; String? get author; String? get imageUrl;
/// Create a copy of ParsedArticle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParsedArticleCopyWith<ParsedArticle> get copyWith => _$ParsedArticleCopyWithImpl<ParsedArticle>(this as ParsedArticle, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ParsedArticle;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParsedArticle&&(identical(other.guid, _this.guid) || other.guid == _this.guid)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.link, _this.link) || other.link == _this.link)&&(identical(other.publishedAt, _this.publishedAt) || other.publishedAt == _this.publishedAt)&&(identical(other.summary, _this.summary) || other.summary == _this.summary)&&(identical(other.contentSnippet, _this.contentSnippet) || other.contentSnippet == _this.contentSnippet)&&(identical(other.fullContentHtml, _this.fullContentHtml) || other.fullContentHtml == _this.fullContentHtml)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.imageUrl, _this.imageUrl) || other.imageUrl == _this.imageUrl));
}


@override
int get hashCode {
  final _this = this as ParsedArticle;
  return Object.hash(runtimeType,_this.guid,_this.title,_this.link,_this.publishedAt,_this.summary,_this.contentSnippet,_this.fullContentHtml,_this.author,_this.imageUrl);
}

@override
String toString() {
  final _this = this as ParsedArticle;
  return 'ParsedArticle(guid: ${_this.guid}, title: ${_this.title}, link: ${_this.link}, publishedAt: ${_this.publishedAt}, summary: ${_this.summary}, contentSnippet: ${_this.contentSnippet}, fullContentHtml: ${_this.fullContentHtml}, author: ${_this.author}, imageUrl: ${_this.imageUrl})';
}


}

/// @nodoc
abstract mixin class $ParsedArticleCopyWith<$Res>  {
  factory $ParsedArticleCopyWith(ParsedArticle value, $Res Function(ParsedArticle) _then) = _$ParsedArticleCopyWithImpl;
@useResult
$Res call({
 String guid, String title, String link, DateTime publishedAt, String? summary, String? contentSnippet, String? fullContentHtml, String? author, String? imageUrl
});




}
/// @nodoc
class _$ParsedArticleCopyWithImpl<$Res>
    implements $ParsedArticleCopyWith<$Res> {
  _$ParsedArticleCopyWithImpl(this._self, this._then);

  final ParsedArticle _self;
  final $Res Function(ParsedArticle) _then;

/// Create a copy of ParsedArticle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? guid = null,Object? title = null,Object? link = null,Object? publishedAt = null,Object? summary = freezed,Object? contentSnippet = freezed,Object? fullContentHtml = freezed,Object? author = freezed,Object? imageUrl = freezed,}) {
  return _then(ParsedArticle(
guid: null == guid ? _self.guid : guid // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String?,contentSnippet: freezed == contentSnippet ? _self.contentSnippet : contentSnippet // ignore: cast_nullable_to_non_nullable
as String?,fullContentHtml: freezed == fullContentHtml ? _self.fullContentHtml : fullContentHtml // ignore: cast_nullable_to_non_nullable
as String?,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ParsedArticle].
extension ParsedArticlePatterns on ParsedArticle {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ParsedArticle value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ParsedArticle() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ParsedArticle value)  $default,){
final _that = this;
switch (_that) {
case _ParsedArticle():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ParsedArticle value)?  $default,){
final _that = this;
switch (_that) {
case _ParsedArticle() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String guid,  String title,  String link,  DateTime publishedAt,  String? summary,  String? contentSnippet,  String? fullContentHtml,  String? author,  String? imageUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ParsedArticle() when $default != null:
return $default(_that.guid,_that.title,_that.link,_that.publishedAt,_that.summary,_that.contentSnippet,_that.fullContentHtml,_that.author,_that.imageUrl);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String guid,  String title,  String link,  DateTime publishedAt,  String? summary,  String? contentSnippet,  String? fullContentHtml,  String? author,  String? imageUrl)  $default,) {final _that = this;
switch (_that) {
case _ParsedArticle():
return $default(_that.guid,_that.title,_that.link,_that.publishedAt,_that.summary,_that.contentSnippet,_that.fullContentHtml,_that.author,_that.imageUrl);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String guid,  String title,  String link,  DateTime publishedAt,  String? summary,  String? contentSnippet,  String? fullContentHtml,  String? author,  String? imageUrl)?  $default,) {final _that = this;
switch (_that) {
case _ParsedArticle() when $default != null:
return $default(_that.guid,_that.title,_that.link,_that.publishedAt,_that.summary,_that.contentSnippet,_that.fullContentHtml,_that.author,_that.imageUrl);case _:
  return null;

}
}

}

/// @nodoc


class _ParsedArticle implements ParsedArticle {
  const _ParsedArticle({required this.guid, required this.title, required this.link, required this.publishedAt, this.summary, this.contentSnippet, this.fullContentHtml, this.author, this.imageUrl});
  

@override final  String guid;
@override final  String title;
@override final  String link;
@override final  DateTime publishedAt;
@override final  String? summary;
@override final  String? contentSnippet;
@override final  String? fullContentHtml;
@override final  String? author;
@override final  String? imageUrl;

/// Create a copy of ParsedArticle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ParsedArticleCopyWith<_ParsedArticle> get copyWith => __$ParsedArticleCopyWithImpl<_ParsedArticle>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ParsedArticle&&(identical(other.guid, guid) || other.guid == guid)&&(identical(other.title, title) || other.title == title)&&(identical(other.link, link) || other.link == link)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.contentSnippet, contentSnippet) || other.contentSnippet == contentSnippet)&&(identical(other.fullContentHtml, fullContentHtml) || other.fullContentHtml == fullContentHtml)&&(identical(other.author, author) || other.author == author)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl));
}


@override
int get hashCode {
    return Object.hash(runtimeType,guid,title,link,publishedAt,summary,contentSnippet,fullContentHtml,author,imageUrl);
}

@override
String toString() {
    return 'ParsedArticle(guid: $guid, title: $title, link: $link, publishedAt: $publishedAt, summary: $summary, contentSnippet: $contentSnippet, fullContentHtml: $fullContentHtml, author: $author, imageUrl: $imageUrl)';
}


}

/// @nodoc
abstract mixin class _$ParsedArticleCopyWith<$Res> implements $ParsedArticleCopyWith<$Res> {
  factory _$ParsedArticleCopyWith(_ParsedArticle value, $Res Function(_ParsedArticle) _then) = __$ParsedArticleCopyWithImpl;
@override @useResult
$Res call({
 String guid, String title, String link, DateTime publishedAt, String? summary, String? contentSnippet, String? fullContentHtml, String? author, String? imageUrl
});




}
/// @nodoc
class __$ParsedArticleCopyWithImpl<$Res>
    implements _$ParsedArticleCopyWith<$Res> {
  __$ParsedArticleCopyWithImpl(this._self, this._then);

  final _ParsedArticle _self;
  final $Res Function(_ParsedArticle) _then;

/// Create a copy of ParsedArticle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? guid = null,Object? title = null,Object? link = null,Object? publishedAt = null,Object? summary = freezed,Object? contentSnippet = freezed,Object? fullContentHtml = freezed,Object? author = freezed,Object? imageUrl = freezed,}) {
  return _then(_ParsedArticle(
guid: null == guid ? _self.guid : guid // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String?,contentSnippet: freezed == contentSnippet ? _self.contentSnippet : contentSnippet // ignore: cast_nullable_to_non_nullable
as String?,fullContentHtml: freezed == fullContentHtml ? _self.fullContentHtml : fullContentHtml // ignore: cast_nullable_to_non_nullable
as String?,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$SourceRef {

 int get id; String get feedUrl; SourceType get type; String? get etag; String? get lastModified;
/// Create a copy of SourceRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourceRefCopyWith<SourceRef> get copyWith => _$SourceRefCopyWithImpl<SourceRef>(this as SourceRef, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SourceRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SourceRef&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.feedUrl, _this.feedUrl) || other.feedUrl == _this.feedUrl)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.etag, _this.etag) || other.etag == _this.etag)&&(identical(other.lastModified, _this.lastModified) || other.lastModified == _this.lastModified));
}


@override
int get hashCode {
  final _this = this as SourceRef;
  return Object.hash(runtimeType,_this.id,_this.feedUrl,_this.type,_this.etag,_this.lastModified);
}

@override
String toString() {
  final _this = this as SourceRef;
  return 'SourceRef(id: ${_this.id}, feedUrl: ${_this.feedUrl}, type: ${_this.type}, etag: ${_this.etag}, lastModified: ${_this.lastModified})';
}


}

/// @nodoc
abstract mixin class $SourceRefCopyWith<$Res>  {
  factory $SourceRefCopyWith(SourceRef value, $Res Function(SourceRef) _then) = _$SourceRefCopyWithImpl;
@useResult
$Res call({
 int id, String feedUrl, SourceType type, String? etag, String? lastModified
});




}
/// @nodoc
class _$SourceRefCopyWithImpl<$Res>
    implements $SourceRefCopyWith<$Res> {
  _$SourceRefCopyWithImpl(this._self, this._then);

  final SourceRef _self;
  final $Res Function(SourceRef) _then;

/// Create a copy of SourceRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? feedUrl = null,Object? type = null,Object? etag = freezed,Object? lastModified = freezed,}) {
  return _then(SourceRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,feedUrl: null == feedUrl ? _self.feedUrl : feedUrl // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as SourceType,etag: freezed == etag ? _self.etag : etag // ignore: cast_nullable_to_non_nullable
as String?,lastModified: freezed == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SourceRef].
extension SourceRefPatterns on SourceRef {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SourceRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SourceRef() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SourceRef value)  $default,){
final _that = this;
switch (_that) {
case _SourceRef():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SourceRef value)?  $default,){
final _that = this;
switch (_that) {
case _SourceRef() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String feedUrl,  SourceType type,  String? etag,  String? lastModified)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SourceRef() when $default != null:
return $default(_that.id,_that.feedUrl,_that.type,_that.etag,_that.lastModified);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String feedUrl,  SourceType type,  String? etag,  String? lastModified)  $default,) {final _that = this;
switch (_that) {
case _SourceRef():
return $default(_that.id,_that.feedUrl,_that.type,_that.etag,_that.lastModified);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String feedUrl,  SourceType type,  String? etag,  String? lastModified)?  $default,) {final _that = this;
switch (_that) {
case _SourceRef() when $default != null:
return $default(_that.id,_that.feedUrl,_that.type,_that.etag,_that.lastModified);case _:
  return null;

}
}

}

/// @nodoc


class _SourceRef implements SourceRef {
  const _SourceRef({required this.id, required this.feedUrl, required this.type, this.etag, this.lastModified});
  

@override final  int id;
@override final  String feedUrl;
@override final  SourceType type;
@override final  String? etag;
@override final  String? lastModified;

/// Create a copy of SourceRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SourceRefCopyWith<_SourceRef> get copyWith => __$SourceRefCopyWithImpl<_SourceRef>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceRef&&(identical(other.id, id) || other.id == id)&&(identical(other.feedUrl, feedUrl) || other.feedUrl == feedUrl)&&(identical(other.type, type) || other.type == type)&&(identical(other.etag, etag) || other.etag == etag)&&(identical(other.lastModified, lastModified) || other.lastModified == lastModified));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,feedUrl,type,etag,lastModified);
}

@override
String toString() {
    return 'SourceRef(id: $id, feedUrl: $feedUrl, type: $type, etag: $etag, lastModified: $lastModified)';
}


}

/// @nodoc
abstract mixin class _$SourceRefCopyWith<$Res> implements $SourceRefCopyWith<$Res> {
  factory _$SourceRefCopyWith(_SourceRef value, $Res Function(_SourceRef) _then) = __$SourceRefCopyWithImpl;
@override @useResult
$Res call({
 int id, String feedUrl, SourceType type, String? etag, String? lastModified
});




}
/// @nodoc
class __$SourceRefCopyWithImpl<$Res>
    implements _$SourceRefCopyWith<$Res> {
  __$SourceRefCopyWithImpl(this._self, this._then);

  final _SourceRef _self;
  final $Res Function(_SourceRef) _then;

/// Create a copy of SourceRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? feedUrl = null,Object? type = null,Object? etag = freezed,Object? lastModified = freezed,}) {
  return _then(_SourceRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,feedUrl: null == feedUrl ? _self.feedUrl : feedUrl // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as SourceType,etag: freezed == etag ? _self.etag : etag // ignore: cast_nullable_to_non_nullable
as String?,lastModified: freezed == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$FetchResult {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FetchResult);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'FetchResult()';
}


}

/// @nodoc
class $FetchResultCopyWith<$Res>  {
$FetchResultCopyWith(FetchResult _, $Res Function(FetchResult) __);
}


/// Adds pattern-matching-related methods to [FetchResult].
extension FetchResultPatterns on FetchResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( FetchFresh value)?  fresh,TResult Function( FetchUnchanged value)?  unchanged,TResult Function( FetchFailed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case FetchFresh() when fresh != null:
return fresh(_that);case FetchUnchanged() when unchanged != null:
return unchanged(_that);case FetchFailed() when failed != null:
return failed(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( FetchFresh value)  fresh,required TResult Function( FetchUnchanged value)  unchanged,required TResult Function( FetchFailed value)  failed,}){
final _that = this;
switch (_that) {
case FetchFresh():
return fresh(_that);case FetchUnchanged():
return unchanged(_that);case FetchFailed():
return failed(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( FetchFresh value)?  fresh,TResult? Function( FetchUnchanged value)?  unchanged,TResult? Function( FetchFailed value)?  failed,}){
final _that = this;
switch (_that) {
case FetchFresh() when fresh != null:
return fresh(_that);case FetchUnchanged() when unchanged != null:
return unchanged(_that);case FetchFailed() when failed != null:
return failed(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( List<ParsedArticle> articles,  String? etag,  String? lastModified)?  fresh,TResult Function()?  unchanged,TResult Function( String message)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case FetchFresh() when fresh != null:
return fresh(_that.articles,_that.etag,_that.lastModified);case FetchUnchanged() when unchanged != null:
return unchanged();case FetchFailed() when failed != null:
return failed(_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( List<ParsedArticle> articles,  String? etag,  String? lastModified)  fresh,required TResult Function()  unchanged,required TResult Function( String message)  failed,}) {final _that = this;
switch (_that) {
case FetchFresh():
return fresh(_that.articles,_that.etag,_that.lastModified);case FetchUnchanged():
return unchanged();case FetchFailed():
return failed(_that.message);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( List<ParsedArticle> articles,  String? etag,  String? lastModified)?  fresh,TResult? Function()?  unchanged,TResult? Function( String message)?  failed,}) {final _that = this;
switch (_that) {
case FetchFresh() when fresh != null:
return fresh(_that.articles,_that.etag,_that.lastModified);case FetchUnchanged() when unchanged != null:
return unchanged();case FetchFailed() when failed != null:
return failed(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class FetchFresh implements FetchResult {
  const FetchFresh({required  List<ParsedArticle> articles, this.etag, this.lastModified}): _articles = articles;
  

 final  List<ParsedArticle> _articles;
 List<ParsedArticle> get articles {
  if (_articles is EqualUnmodifiableListView) return _articles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_articles);
}

 final  String? etag;
 final  String? lastModified;

/// Create a copy of FetchResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FetchFreshCopyWith<FetchFresh> get copyWith => _$FetchFreshCopyWithImpl<FetchFresh>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FetchFresh&&const DeepCollectionEquality().equals(other.articles, _articles)&&(identical(other.etag, etag) || other.etag == etag)&&(identical(other.lastModified, lastModified) || other.lastModified == lastModified));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_articles),etag,lastModified);
}

@override
String toString() {
    return 'FetchResult.fresh(articles: $articles, etag: $etag, lastModified: $lastModified)';
}


}

/// @nodoc
abstract mixin class $FetchFreshCopyWith<$Res> implements $FetchResultCopyWith<$Res> {
  factory $FetchFreshCopyWith(FetchFresh value, $Res Function(FetchFresh) _then) = _$FetchFreshCopyWithImpl;
@useResult
$Res call({
 List<ParsedArticle> articles, String? etag, String? lastModified
});




}
/// @nodoc
class _$FetchFreshCopyWithImpl<$Res>
    implements $FetchFreshCopyWith<$Res> {
  _$FetchFreshCopyWithImpl(this._self, this._then);

  final FetchFresh _self;
  final $Res Function(FetchFresh) _then;

/// Create a copy of FetchResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? articles = null,Object? etag = freezed,Object? lastModified = freezed,}) {
  return _then(FetchFresh(
articles: null == articles ? _self._articles : articles // ignore: cast_nullable_to_non_nullable
as List<ParsedArticle>,etag: freezed == etag ? _self.etag : etag // ignore: cast_nullable_to_non_nullable
as String?,lastModified: freezed == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class FetchUnchanged implements FetchResult {
  const FetchUnchanged();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FetchUnchanged);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'FetchResult.unchanged()';
}


}




/// @nodoc


class FetchFailed implements FetchResult {
  const FetchFailed(this.message);
  

 final  String message;

/// Create a copy of FetchResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FetchFailedCopyWith<FetchFailed> get copyWith => _$FetchFailedCopyWithImpl<FetchFailed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FetchFailed&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'FetchResult.failed(message: $message)';
}


}

/// @nodoc
abstract mixin class $FetchFailedCopyWith<$Res> implements $FetchResultCopyWith<$Res> {
  factory $FetchFailedCopyWith(FetchFailed value, $Res Function(FetchFailed) _then) = _$FetchFailedCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$FetchFailedCopyWithImpl<$Res>
    implements $FetchFailedCopyWith<$Res> {
  _$FetchFailedCopyWithImpl(this._self, this._then);

  final FetchFailed _self;
  final $Res Function(FetchFailed) _then;

/// Create a copy of FetchResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(FetchFailed(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
