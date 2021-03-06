{-# LANGUAGE CPP #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE OverloadedStrings #-}
module UIDockerExec(
  testUIDockerExec, 
  uiDockerExec, 
  initialDockerExecInfo, 
  DockerExecInfo,
  getContainer,
  getCommand,
  getCancel) where

import qualified Data.Text as T
import Lens.Micro ((^.))
import Lens.Micro.TH
import qualified Graphics.Vty as V
import Brick
    ( BrickEvent(VtyEvent),
      Widget,
      App(..),
      AttrMap,
      attrMap,
      continue,
      customMain,
      halt,
      on,
      (<+>),
      (<=>),
      fill,
      hLimit,
      padBottom,
      padTop,
      str,
      vLimit,
      Padding(Pad) )
import Brick.Forms
  ( Form
  , newForm
  , formState
  , formFocus
  , setFieldValid
  , renderForm
  , handleFormEvent
  , invalidFields
  , allFieldsValid
  , focusedFormInputAttr
  , invalidFormInputAttr
  , checkboxField
  , radioField
  , editShowableField
  , editTextField
  , editPasswordField
  , (@@=)
  )
import Brick.Focus
  ( focusGetCurrent
  , focusRingCursor
  )
import qualified Brick.Widgets.Edit as E
import qualified Brick.Widgets.Border as B
import qualified Brick.Widgets.Center as C

data Name = NameField | CommandField
          deriving (Eq, Ord, Show)

data DockerExecInfo =
    DockerExecInfo { _container    :: T.Text
                   ,_command      :: T.Text
                   ,_cancel             :: Bool
             }
             deriving (Show)

makeLenses ''DockerExecInfo

getContainer :: DockerExecInfo -> T.Text
getContainer = _container

getCommand :: DockerExecInfo -> T.Text
getCommand = _command

getCancel :: DockerExecInfo -> Bool
getCancel = _cancel

-- This form is covered in the Brick User Guide; see the "Input Forms"
-- section.
mkForm :: DockerExecInfo -> Form DockerExecInfo e Name
mkForm =
    let label s w = padBottom (Pad 1) $
                    (vLimit 1 $ hLimit 15 $ str s <+> fill ' ') <+> w
    in newForm [ label "Container" @@=
                   editTextField container NameField (Just 1)
                ,label "Command" @@=
                   editTextField command CommandField (Just 1)
               ]

theMap :: AttrMap
theMap = attrMap V.defAttr
  [ (E.editAttr, V.white `on` V.black)
  , (E.editFocusedAttr, V.white `on` V.blue)
  , (invalidFormInputAttr, V.white `on` V.red)
  , (focusedFormInputAttr, V.white `on` V.blue)
  ]

draw :: Form DockerExecInfo e Name -> [Widget Name]
draw f = [C.vCenter $ C.hCenter form <=> C.hCenter help]
    where
        form = B.borderWithLabel (str "Run Command") $ padTop (Pad 1) $ hLimit 80 $ renderForm f
        help = padTop (Pad 1) body
        body = str "Press <Enter> to continue; Press <Esc> to exit"

app :: App (Form DockerExecInfo e Name) e Name
app =
    App { appDraw = draw
        , appHandleEvent = \s ev ->
            case ev of
                VtyEvent (V.EvResize {})     -> continue s
                VtyEvent (V.EvKey V.KEsc [])   -> halt $ mkForm (formState s){_cancel = True}
                -- Enter quits only when we aren't in the multi-line editor.
                VtyEvent (V.EvKey V.KEnter []) -> halt $ mkForm (formState s){_cancel = False }
                _ -> do
                    s' <- handleFormEvent ev s
                    continue s'

        , appChooseCursor = focusRingCursor formFocus
        , appStartEvent = return
        , appAttrMap = const theMap
        }


initialDockerExecInfo :: DockerExecInfo
initialDockerExecInfo = DockerExecInfo { _container = ""
                                      ,_cancel = False
                                      ,_command = ""
                            }

uiDockerExec :: DockerExecInfo -> IO DockerExecInfo
uiDockerExec oldInfo = do
    let buildVty = do
          v <- V.mkVty =<< V.standardIOConfig
          V.setMode (V.outputIface v) V.Mouse True
          return v

        f = mkForm oldInfo

    initialVty <- buildVty
    f' <- customMain initialVty buildVty Nothing app f
    return $ formState f'

testUIDockerExec :: IO ()
testUIDockerExec = do
    newInfo <- uiDockerExec initialDockerExecInfo

    putStrLn "The starting form state was:"
    print initialDockerExecInfo

    putStrLn "The final form state was:"
    print newInfo