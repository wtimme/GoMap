describe Fastlane::Actions::GomapAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The gomap plugin is working!")

      Fastlane::Actions::GomapAction.run(nil)
    end
  end
end
