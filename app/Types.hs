{-# LANGUAGE NoMonomorphismRestriction, FlexibleContexts, ConstraintKinds #-}

module Types (
  Icon(..),
  SyntaxNode(..),
  NodeName(..),
  Port(..),
  NameAndPort(..),
  Connection,
  Edge(..),
  EdgeOption(..),
  EdgeEnd(..),
  Drawing(..),
  IDState(..),
  SpecialQDiagram,
  SpecialBackend,
  SpecialNum,
  SgNamedNode(..),
  IngSyntaxGraph,
  LikeApplyFlavor(..),
  CaseOrGuardTag(..)
) where

import Diagrams.Prelude(QDiagram, V2, Any, Renderable, Path, IsName)
import Diagrams.TwoD.Text(Text)

import Data.Typeable(Typeable)

-- TYPES --
-- | A datatype that represents an icon.
-- The TextBoxIcon's data is the text that appears in the text box.
-- The LambdaRegionIcon's data is the number of lambda ports, and the name of it's
-- subdrawing.
data Icon = TextBoxIcon String | GuardIcon Int
  | FlatLambdaIcon [String] | ApplyAIcon Int | ComposeIcon Int
  | PAppIcon Int String | CaseIcon Int | CaseResultIcon
  | BindTextBoxIcon String
  -- TODO: NestedApply should have the type NestedApply (Maybe (Name, Icon)) [Maybe (Name, Icon)]
  | NestedApply LikeApplyFlavor [Maybe (NodeName, Icon)]
  | NestedPApp [(Maybe (NodeName, Icon), String)]
  | NestedCaseIcon [Maybe (NodeName, Icon)]
  | NestedGuardIcon [Maybe (NodeName, Icon)]
  deriving (Show, Eq, Ord)

data LikeApplyFlavor = ApplyNodeFlavor | ComposeNodeFlavor deriving (Show, Eq, Ord)

data CaseOrGuardTag = CaseTag | GuardTag deriving (Show, Eq, Ord)

-- TODO remove Ints from SyntaxNode data constructors.
data SyntaxNode =
  LikeApplyNode LikeApplyFlavor Int -- Function application, composition, and applying to a composition
  | NestedApplyNode LikeApplyFlavor Int [(SgNamedNode, Edge)]
  | PatternApplyNode String Int -- Destructors as used in patterns
  -- | NestedPatternApplyNode String Int [(SgNamedNode, Edge)]
  | NestedPatternApplyNode String [(Maybe SgNamedNode, String)]
  | NameNode String -- Identifiers or symbols
  | BindNameNode String
  | LiteralNode String -- Literal values like the string "Hello World"
  | FunctionDefNode [String] -- Function definition (ie. lambda expression)
  | GuardNode Int
  | CaseNode Int
  | CaseResultNode -- TODO remove caseResultNode
  | NestedCaseOrGuardNode CaseOrGuardTag Int [(SgNamedNode, Edge)]
  deriving (Show, Eq, Ord)

newtype NodeName = NodeName Int deriving (Typeable, Eq, Ord, Show)
instance IsName NodeName

newtype Port = Port Int deriving (Typeable, Eq, Ord, Show)
instance IsName Port

data NameAndPort = NameAndPort NodeName (Maybe Port) deriving (Show, Eq, Ord)

type Connection = (NameAndPort, NameAndPort)

data EdgeOption = EdgeInPattern deriving (Show, Eq, Ord)

-- | An Edge has an name of the source icon, and its optional port number,
-- and the name of the destination icon, and its optional port number.
data Edge = Edge {edgeOptions::[EdgeOption], edgeEnds :: (EdgeEnd, EdgeEnd), edgeConnection :: Connection}
  deriving (Show, Eq, Ord)

data EdgeEnd = EndAp1Result | EndAp1Arg | EndNone deriving (Show, Eq, Ord)

-- | A drawing is a map from names to Icons, a list of edges,
-- and a map of names to subDrawings
data Drawing = Drawing [(NodeName, Icon)] [Edge] deriving (Show, Eq)

data SgNamedNode = SgNamedNode NodeName SyntaxNode deriving (Ord, Eq, Show)

-- | IDState is an Abstract Data Type that is used as a state whose value is a unique id.
newtype IDState = IDState Int deriving (Eq, Show)

type SpecialNum n = (Floating n, RealFrac n, RealFloat n, Typeable n, Show n, Enum n)

-- Note that SpecialBackend is a constraint synonym, not a type synonym.
type SpecialBackend b n = (SpecialNum n, Renderable (Path V2 n) b, Renderable (Text n) b)

type SpecialQDiagram b n = QDiagram b V2 n Any

type IngSyntaxGraph gr = gr SgNamedNode Edge
