module Language.ImProve.Code (code) where

import Data.List
import Text.Printf

import Language.ImProve.Core
import Language.ImProve.Tree hiding (Branch)
import qualified Language.ImProve.Tree as T

-- | Generate C code.
code :: Name -> Statement -> IO ()
code name stmt = do
  writeFile (name ++ ".c") $
       "/* Generated by ImProve. */\n\n"
    ++ "#include <assert.h>\n\n"
    ++ codeVariables True scope ++ "\n"
    ++ "void " ++ name ++ "()\n{\n"
    ++ indent (codeStmt stmt)
    ++ "}\n\n"
  writeFile (name ++ ".h") $
       "/* Generated by ImProve. */\n\n"
    ++ codeVariables False scope ++ "\n"
    ++ "void " ++ name ++ "(void);\n\n"
  where
  scope = case tree (\ (_, path, _) -> path) $ stmtVars stmt of
    [] -> error "program contains no usefull statements"
    a  -> T.Branch (name ++ "_variables") a

  codeStmt :: Statement -> String
  codeStmt a = case a of
    AssignBool  a b -> name ++ "_variables." ++ pathName a ++ " = " ++ codeExpr b ++ ";\n"
    AssignInt   a b -> name ++ "_variables." ++ pathName a ++ " = " ++ codeExpr b ++ ";\n"
    AssignFloat a b -> name ++ "_variables." ++ pathName a ++ " = " ++ codeExpr b ++ ";\n"
    Branch a b Null -> "if (" ++ codeExpr a ++ ") {\n" ++ indent (codeStmt b) ++ "}\n"
    Branch a b c    -> "if (" ++ codeExpr a ++ ") {\n" ++ indent (codeStmt b) ++ "}\nelse {\n" ++ indent (codeStmt c) ++ "}\n"
    Sequence a b -> codeStmt a ++ codeStmt b
    Assert a -> "assert(" ++ codeExpr a ++ ");\n"
    Assume a -> "assert(" ++ codeExpr a ++ ");\n"
    Label  name a -> "/*" ++ name ++ "*/\n" ++ indent (codeStmt a)
    Null -> ""
  
  codeExpr :: E a -> String
  codeExpr a = case a of
    Ref a     -> name ++ "_variables." ++ pathName a
    Const a   -> showConst $ const' a
    Add a b   -> group [codeExpr a, "+", codeExpr b]
    Sub a b   -> group [codeExpr a, "-", codeExpr b]
    Mul a b   -> group [codeExpr a, "*", showConst (const' b)]
    Div a b   -> group [codeExpr a, "/", showConst (const' b)]
    Mod a b   -> group [codeExpr a, "%", showConst (const' b)]
    Not a     -> group ["!", codeExpr a]
    And a b   -> group [codeExpr a, "&&",  codeExpr b]
    Or  a b   -> group [codeExpr a, "||",  codeExpr b]
    Eq  a b   -> group [codeExpr a, "==",  codeExpr b]
    Lt  a b   -> group [codeExpr a, "<",   codeExpr b]
    Gt  a b   -> group [codeExpr a, ">",   codeExpr b]
    Le  a b   -> group [codeExpr a, "<=",  codeExpr b]
    Ge  a b   -> group [codeExpr a, ">=",  codeExpr b]
    Mux a b c -> group [codeExpr a, "?", codeExpr b, ":", codeExpr c] 
    where
    group :: [String] -> String
    group a = "(" ++ intercalate " " a ++ ")"

indent :: String -> String
indent = unlines . map ("\t" ++) . lines

indent' :: String -> String
indent' a = case lines a of
  [] -> []
  (a:b) -> a ++ "\n" ++ indent (unlines b)

codeVariables :: Bool -> (Tree Name (Bool, Path, Const)) -> String
codeVariables define a = (if define then "" else "extern ") ++ init (init (f1 a)) ++ (if define then " =\n    " ++ f2 a else "") ++ ";\n"
  where
  f1 a = case a of
    T.Branch name items -> "struct {  /* " ++ name ++ " */\n" ++ indent (concatMap f1 items) ++ "} " ++ name ++ ";\n"
    Leaf name (input, _, init) -> printf "%-5s %-25s;%s\n" (showConstType init) name (if input then "  /* input */" else "")

  f2 a = case a of
    T.Branch name items -> indent' $ "{   " ++ (intercalate ",   " $ map f2 items) ++ "}  /* " ++ name ++ " */\n"
    Leaf name (_, _, init) -> printf "%-15s  /* %s */\n" (showConst init) name

showConst :: Const -> String
showConst a = case a of
  Bool  True  -> "1"
  Bool  False -> "0"
  Int   a     -> show a
  Float a     -> show a

showConstType :: Const -> String
showConstType a = case a of
  Bool  _ -> "int"
  Int   _ -> "int"
  Float _ -> "float"

