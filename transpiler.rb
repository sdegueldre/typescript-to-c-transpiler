#!/usr/bin/env ruby

class Lexer
  TOKEN_TYPES = [
    [:funcdef, /\bfunction\b/],
    [:identifier, /\b[a-zA-Z]+\b/],
    [:integer, /\b[0-9]+\b/],
    [:oparen, /\(/],
    [:cparen, /\)/],
    [:obrace, /\{/],
    [:cbrace, /\}/],
    [:colon, /\:/],
    [:comma, /,/],
    [:semicolon, /\;/]
  ]

  def initialize(code)
    @code = code
  end

  def tokenize
    tokens = []
    until @code.empty?
      tokens << tokenize_one_token
      @code = @code.strip
    end
    tokens
  end

  def tokenize_one_token
    TOKEN_TYPES.each do |type, re|
      re = /\A(#{re})/
      if @code =~ re
        value = $1
        @code = @code[value.length..-1]
        return Token.new(type, value)
      end
    end
    raise RuntimeError.new(
      "Couldn't match token on #{@code.inspect}"
    )
  end
end

class Parser
  def initialize(tokens)
    @tokens = tokens
  end

  def parse
    parse_funcdef
  end

  def parse_funcdef
    consume(:funcdef)
    name = consume(:identifier).value
    args = parse_args
    consume(:colon)
    ret_type = consume(:identifier).value
    body = parse_block
    FuncdefNode.new(name, args, ret_type, body)
  end

  def parse_args
    args = []
    consume(:oparen)
    if peek(:identifier)
      args << parse_one_arg
      while peek(:comma)
        consume(:comma)
        args << parse_one_arg
      end
    end
    consume(:cparen)
    args
  end

  def parse_one_arg
    name = consume(:identifier).value
    consume(:colon)
    type = consume(:identifier).value
    return ArgNode.new(name, type)
  end

  def parse_block
    exprs = []
    consume(:obrace)
    exprs << parse_expr
    consume(:semicolon)
    while !peek(:cbrace)
      exprs << parse_expr
      consume(:semicolon)
    end
    consume(:cbrace)
    exprs
  end

  def parse_expr
    if peek(:integer)
      node = parse_integer
    elsif peek(:identifier)
      if peek(:oparen, 1)
        node = parse_call
      else
        node = parse_var
      end
    end
    node
  end

  def parse_integer
    IntegerNode.new(consume(:integer).value.to_i)
  end

  def parse_call
    arg_exprs = []
    name = consume(:identifier).value
    consume(:oparen)
    if !peek(:cparen)
      arg_exprs << parse_expr
      while peek(:comma)
        consume(:comma)
        arg_exprs << parse_expr
      end
    end
    consume(:cparen)
    CallNode.new(name, arg_exprs)
  end

  def parse_var
    VarNode.new(consume(:identifier).value)
  end

  def consume(expected_type)
    token = @tokens.shift
    if token.type == expected_type
      token
    else
      raise RuntimeError.new("Expected token type #{expected_type.inspect} but got #{token.type.inspect}")
    end
  end

  def peek(expected_type, offset=0)
    expected_type == @tokens[offset].type
  end
end

Token = Struct.new(:type, :value)
FuncdefNode = Struct.new(:name, :args, :ret_type, :body)
IntegerNode = Struct.new(:value)
ArgNode = Struct.new(:name, :type)
CallNode = Struct.new(:name, :arg_exprs)
VarNode = Struct.new(:name)

class Generator
  def generate(node)
    case node
    when FuncdefNode
      "%s %s(%s){\n\t%s;\n}" % [
        node.ret_type,
        node.name,
        node.args.map{|arg| generate(arg)}.join(", "),
        node.body.map{|expr| generate(expr)}.join(";")
      ]
    when ArgNode
      "%s %s" % [
        node.type,
        node.name
      ]
    when CallNode
      "%s(%s)" % [
        node.name,
        node.arg_exprs.map{|expr| generate(expr)}.join(",")
      ]
    when VarNode
      node.name
    when IntegerNode
      node.value
    else
      raise RuntimeError.new("Unexpected node type #{node.class}")
    end
  end
end

tokens = Lexer.new(File.read("program.ts")).tokenize
tree = Parser.new(tokens).parse
code = Generator.new().generate(tree)
puts code
