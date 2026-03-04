{-# LANGUAGE OverloadedStrings #-}

import Hakyll
  ( Context,
    Identifier,
    Tags,
    buildTags,
    compile,
    compressCssCompiler,
    constField,
    create,
    customRoute,
    dateField,
    defaultContext,
    field,
    fromCapture,
    getResourceBody,
    hakyll,
    idRoute,
    listField,
    loadAll,
    loadAndApplyTemplate,
    makeItem,
    match,
    pandocCompiler,
    recentFirst,
    relativizeUrls,
    renderTagList,
    route,
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

  match "posts/*" $ do
    route $ customRoute postRoute
    compile $
      pandocCompiler
        >>= loadAndApplyTemplate "templates/post.html" (postCtxWithTags tags)
        >>= loadAndApplyTemplate "templates/default.html" (postCtxWithTags tags)
        >>= relativizeUrls

  create ["index.html"] $ do
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll "posts/*"
      let indexCtx =
            listField "posts" (postCtxWithTags tags) (pure posts)
              <> field "tagcloud" (const $ renderTagList tags)
              <> constField "title" "Home"
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
  dateField "date" "%Y-%m-%d"
    <> defaultContext

postCtxWithTags :: Tags -> Context String
postCtxWithTags tags =
  tagsField "tags" tags
    <> postCtx

pageNotFoundCtx :: Context String
pageNotFoundCtx =
  constField "title" "Page not found"
    <> defaultContext

postRoute :: Identifier -> FilePath
postRoute ident =
  "posts" </> takeBaseName (toFilePath ident) </> "index.html"
