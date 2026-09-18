module Hunch
  module Questions
    Noul = Data.define(:key, :question, :yes, :no, :threshold) do
      def type = :noul

      def payload
        criteria = { "true" => yes, "false" => no }.compact
        base = { "type" => "noul", "instructions" => question }
        criteria.empty? ? base : base.merge("criteria" => criteria)
      end
    end

    Choice = Data.define(:key, :question, :options) do
      def type = :choice

      def payload
        {
          "type" => "choice",
          "instructions" => question || "Which of these best describes the state?",
          "criteria" => options.transform_keys(&:to_s)
        }
      end
    end

    Rate = Data.define(:key, :question, :levels) do
      def type = :rate

      def payload
        {
          "type" => "score",
          "instructions" => question || "Where does the state sit on this scale?",
          "criteria" => levels.values
        }
      end
    end
  end
end
