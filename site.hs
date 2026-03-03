{-# LANGUAGE OverloadedStrings #-}

import Hakyll
  ( Context,
    Identifier,
    compile,
    compressCssCompiler,
    constField,
    create,
    customRoute,
    dateField,
    defaultContext,
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
    route,
    templateBodyCompiler,
    toFilePath,
  )
import System.FilePath (takeBaseName, (</>))

main :: IO ()
main = hakyll $ do
  match "css/*" $ do
    route idRoute
    compile compressCssCompiler

  match "posts/*" $ do
    route $ customRoute postRoute
    compile $
      pandocCompiler
        >>= loadAndApplyTemplate "templates/post.html" postCtx
        >>= loadAndApplyTemplate "templates/default.html" postCtx
        >>= relativizeUrls

  create ["index.html"] $ do
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll "posts/*"
      let indexCtx =
            listField "posts" postCtx (pure posts)
              <> constField "title" "Home"
              <> defaultContext
      makeItem ("" :: String)
        >>= loadAndApplyTemplate "templates/post-list.html" indexCtx
        >>= loadAndApplyTemplate "templates/default.html" indexCtx
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

pageNotFoundCtx :: Context String
pageNotFoundCtx =
  constField "title" "Page not found"
    <> defaultContext

postRoute :: Identifier -> FilePath
postRoute ident =
  "posts" </> takeBaseName (toFilePath ident) </> "index.html"
