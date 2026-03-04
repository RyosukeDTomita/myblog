{-# LANGUAGE OverloadedStrings #-}

import Hakyll
  ( Context,
    FeedConfiguration (..),
    Identifier,
    Tags,
    bodyField,
    buildTags,
    compile,
    copyFileCompiler,
    compressCssCompiler,
    constField,
    create,
    customRoute,
    dateField,
    defaultContext,
    field,
    feedAuthorEmail,
    feedAuthorName,
    feedDescription,
    feedRoot,
    feedTitle,
    fromCapture,
    getResourceBody,
    hakyll,
    idRoute,
    loadBody,
    listField,
    loadAll,
    loadAllSnapshots,
    loadAndApplyTemplate,
    makeItem,
    match,
    pandocCompiler,
    recentFirst,
    relativizeUrls,
    renderRss,
    renderTagList,
    route,
    saveSnapshot,
    tagsField,
    tagsRules,
    templateBodyCompiler,
    toFilePath,
  )
import System.FilePath (takeBaseName, (</>))

main :: IO ()
main = hakyll $ do
  tags <- buildTags "posts/*" (fromCapture "tags/*/index.html")

  match "css/*" $ do
    route idRoute
    compile compressCssCompiler

  match "images/*" $ do
    route idRoute
    compile copyFileCompiler

  match "js/*" $ do
    route idRoute
    compile copyFileCompiler

  match "posts/*" $ do
    route $ customRoute postRoute
    compile $
      pandocCompiler
        >>= saveSnapshot "content"
        >>= loadAndApplyTemplate "templates/post.html" (postCtxWithTags tags)
        >>= loadAndApplyTemplate "templates/default.html" (postCtxWithTags tags)
        >>= relativizeUrls

  create ["rss.xml"] $ do
    route idRoute
    compile $ do
      posts <- fmap (take 10) . recentFirst =<< loadAllSnapshots "posts/*" "content"
      renderRss feedConfiguration feedCtx posts

  create ["index.html"] $ do
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll "posts/*"
      let indexCtx =
            listField "posts" (postCtxWithTags tags) (pure posts)
              <> field "tagcloud" (const $ renderTagList tags)
              <> constField "title" "Home"
              <> inlineCssField
              <> defaultContext
      makeItem ("" :: String)
        >>= loadAndApplyTemplate "templates/post-list.html" indexCtx
        >>= loadAndApplyTemplate "templates/default.html" indexCtx
        >>= relativizeUrls

  tagsRules tags $ \tag postsPattern -> do
    let title = "Tag: " <> tag
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll postsPattern
      let tagCtx =
            listField "posts" (postCtxWithTags tags) (pure posts)
              <> constField "title" title
              <> inlineCssField
              <> defaultContext
      makeItem ("" :: String)
        >>= loadAndApplyTemplate "templates/post-list.html" tagCtx
        >>= loadAndApplyTemplate "templates/default.html" tagCtx
        >>= relativizeUrls

  create ["tags/index.html"] $ do
    route idRoute
    compile $ do
      let tagsCtx =
            constField "title" "Tag Search"
              <> field "tagcloud" (const $ renderTagList tags)
              <> inlineCssField
              <> defaultContext
      makeItem ("" :: String)
        >>= loadAndApplyTemplate "templates/tags.html" tagsCtx
        >>= loadAndApplyTemplate "templates/default.html" tagsCtx
        >>= relativizeUrls

  match "404.html" $ do
    route idRoute
    compile $
      getResourceBody
        >>= loadAndApplyTemplate "templates/default.html" pageNotFoundCtx
        >>= relativizeUrls

  match "templates/*" $ compile templateBodyCompiler

postCtx :: Context String
postCtx =
  inlineCssField
    <> dateField "date" "%Y-%m-%d"
    <> defaultContext

inlineCssField :: Context String
inlineCssField =
  field "inlineCss" (const $ loadBody "css/default.css")

postCtxWithTags :: Tags -> Context String
postCtxWithTags tags =
  tagsField "tags" tags
    <> postCtx

pageNotFoundCtx :: Context String
pageNotFoundCtx =
  inlineCssField
    <> constField "title" "Page not found"
    <> defaultContext

postRoute :: Identifier -> FilePath
postRoute ident =
  "posts" </> takeBaseName (toFilePath ident) </> "index.html"

feedConfiguration :: FeedConfiguration
feedConfiguration =
  FeedConfiguration
    { feedTitle = "Sigma Secret Base",
      feedDescription = "Ryosuke D. Tomita's blog",
      feedAuthorName = "Ryosuke D. Tomita",
      feedAuthorEmail = "",
      feedRoot = "https://ryosukedtomita.github.io"
    }

feedCtx :: Context String
feedCtx =
  bodyField "description"
    <> dateField "date" "%Y-%m-%d"
    <> defaultContext
