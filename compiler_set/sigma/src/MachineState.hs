module MachineState where

import Control.Monad.State as State
import Data.Word
import qualified Data.ByteString as B

import Debug.Trace

import qualified Register as Reg
import qualified Memory as Mem

data MachineState = MachineState {
      intRegister    :: Reg.RegisterFile
    , floatRegister  :: Reg.RegisterFile
    , memory         :: Mem.Memory
    , program        :: Program
    , programCounter :: ProgramCounter
    , callStack      :: [ProgramCounter]
    , rxInput        :: B.ByteString
    , txOutput       :: B.ByteString
    }

data ExecutionState = Continue | Halt deriving (Show)

type StateTransformer = State MachineState ExecutionState
type Program = [StateTransformer]
type ProgramCounter = Word32

initialState :: Program -> MachineState
initialState prog =
    MachineState { intRegister = Reg.createRegister
                 , floatRegister = Reg.createRegister
                 , memory = Mem.createMemory
                 , program = prog
                 , programCounter = 0
                 , callStack = []
                 , rxInput = B.pack [0, 0, 0, 10]
                 , txOutput = B.empty }

{-| function 'getI'
  
>>> evalState (getI 1) (initialState [])
0

-}

getI :: Int -> State MachineState Word32
getI n = State.get >>= (return . (Reg.get n) . intRegister)

{-| function 'setI'
  
>>> evalState (setI 1 6) (initialState [])
Continue

>>> evalState (setI 1 1025 >> getI 1) (initialState [])
1025

-}

setI :: Int -> Word32 -> State MachineState ExecutionState
setI n value =
    if n == 0 then
        next
    else
        do
          st <- State.get
          State.put st { intRegister = (Reg.set n value) $ intRegister st}
          next

getF :: Int -> State MachineState Word32
getF n = State.get >>= (return . (Reg.get n) . floatRegister)

{-| function 'setF'
  
>>> evalState (setF 1 6) (initialState [])
Continue

>>> evalState (setF 1 1025 >> getF 1) (initialState [])
1025

-}

setF :: Int -> Word32 -> State MachineState ExecutionState
setF n value =
    do st <- State.get
       State.put st { floatRegister = (Reg.set n value) $ floatRegister st}
       next

{-| function 'goto'
  
>>> let (value, state) = runState (goto 1292) (initialState [])
>>> value
Continue
>>> programCounter state
1292

-}

goto :: Word32 -> State MachineState ExecutionState
goto pc =
    do
      st <- get
      put st { programCounter = pc }
      return Continue

next :: State MachineState ExecutionState
next =
    do
      st <- get
      put st { programCounter = programCounter st + 1 }
      return Continue

gotoRelative :: Word32 -> State MachineState ExecutionState
gotoRelative offset =
    do
      st <- get
      let pc = programCounter st
      goto (pc + offset)

{-| function 'halt'
  
>>> evalState halt (initialState [])
Halt

-}

halt :: State MachineState ExecutionState
halt = return Halt

{-| function 'readRx'
  
>>> evalState (readRx >> readRx >> readRx >> readRx) (initialState [])
10
  
-}

readRx :: State MachineState Word32
readRx =
    do
      st <- get
      case B.uncons (rxInput st) of
        Just(hd, tl) ->
            do
              put st {rxInput = tl}
              return (fromIntegral hd)
        Nothing ->
            -- FIXME: What can I do? Handle error
            return 0

{-| function 'sendTx'
  
>>> (B.head . txOutput . execState (sendTx 5)) (initialState [])
5
  
-}

sendTx :: Word32 -> State MachineState ExecutionState
sendTx value =
    do
      st <- get
      put st { txOutput = B.cons (fromIntegral value) (txOutput st) }
      next

{-| function 'mem'
  
>>> evalState (setMem 3 9292 >> mem 3) (initialState [])
9292

-}

mem :: Word32 -> State MachineState Word32
mem address =
    get >>= (return . Mem.get (fromIntegral address) . memory)

setMem :: Word32 -> Word32 -> State MachineState ExecutionState
setMem address value =
    do
      st <- get
      put st { memory = Mem.set (fromIntegral address) value (memory st) }
      next

{-| function 'call'
  
>>> programCounter $ evalState (call 929 >> return) ((initialState []) {programCounter = 224})
224
  
 -}

call :: Word32 -> State MachineState ExecutionState
call address =
    do
      st <- get
      put st { callStack = (programCounter st) : (callStack st) }
      goto address

ret :: State MachineState ExecutionState
ret =
    do
      st <- get
      -- TODO: error report
      let top : rest = callStack st
      put st { callStack = rest }
      goto (top + 1)

fetchInstruction :: State MachineState ExecutionState
fetchInstruction =
    do st <- State.get
       program st !! (fromIntegral $ programCounter st) -- TODO: convert exception into our domain
