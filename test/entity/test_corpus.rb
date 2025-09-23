require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(.*/test/), '').sub(/test_(.*)\.rb/,'\1')

class TestClass < Test::Unit::TestCase
  setup do
    @tmp = TmpFile.tmp_file
    Corpus.corpora_dir = Path.setup(@tmp)
  end

  teardown do
    Open.rm_rf @tmp
  end
  def test_true

    corpus = Corpus.setup('Utilitarianism·v1')

    corpus.documents
    corpus.save 'test.md', 'test'
    assert_include corpus.documents, 'test.md'

    corpus.delete 'test.md'

    refute corpus.documents.include?('test.md')
  end
end

