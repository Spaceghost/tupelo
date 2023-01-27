require 'funl/blobber'

require 'minitest/autorun'

class TestBlobber < Minitest::Test
  OBJECTS = [
    [ {a: 1, b: 2}, {"a" => 1, "b" => 2} ]
  ]

  def test_marshal
    blobber = Funl::Blobber.for ObjectStream::MARSHAL_TYPE
    OBJECTS.each do |sym_obj, str_obj|
      assert_equal sym_obj, blobber.load(blobber.dump(sym_obj))
      assert_equal str_obj, blobber.load(blobber.dump(str_obj))
    end
  end

  def test_yaml
    blobber = Funl::Blobber.for ObjectStream::YAML_TYPE
    OBJECTS.each do |sym_obj, str_obj|
      assert_equal sym_obj, blobber.load(blobber.dump(sym_obj))
      assert_equal str_obj, blobber.load(blobber.dump(str_obj))
    end
  end

  def test_json_string_keys
    blobber = Funl::Blobber.for ObjectStream::JSON_TYPE
    OBJECTS.each do |sym_obj, str_obj|
      assert_equal str_obj, blobber.load(blobber.dump(sym_obj))
      assert_equal str_obj, blobber.load(blobber.dump(str_obj))
    end
  end

  def test_json_symbol_keys
    blobber = Funl::Blobber.for ObjectStream::JSON_TYPE, symbolize_keys: true
    OBJECTS.each do |sym_obj, str_obj|
      assert_equal sym_obj, blobber.load(blobber.dump(sym_obj))
      assert_equal sym_obj, blobber.load(blobber.dump(str_obj))
    end
  end

  def test_msgpack_string_keys
    blobber = Funl::Blobber.for ObjectStream::MSGPACK_TYPE
    OBJECTS.each do |sym_obj, str_obj|
      assert_equal str_obj, blobber.load(blobber.dump(sym_obj))
      assert_equal str_obj, blobber.load(blobber.dump(str_obj))
    end
  end

  def test_msgpack_symbol_keys
    blobber = Funl::Blobber.for ObjectStream::MSGPACK_TYPE, symbolize_keys: true
    OBJECTS.each do |sym_obj, str_obj|
      assert_equal sym_obj, blobber.load(blobber.dump(sym_obj))
      assert_equal sym_obj, blobber.load(blobber.dump(str_obj))
    end
  end
end

