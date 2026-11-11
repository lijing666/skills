import { Button } from "antd";
import { ArrowLeftOutlined } from "@ant-design/icons";

// 页面门牌（判据正源: composition-layer.md 页面段——只承载标题、描述与返回导航；
// 返回箭头与标题同行垂直居中（titleline），描述独立在标题下方；
// 右侧禁任何操作控件，数据操作按语义归位）
type PageHeaderProps = {
  title: string;
  description?: string;
  onBack?: () => void;
};

export default function PageHeader({ title, description, onBack }: PageHeaderProps) {
  return (
    <header className="jjui-page-header">
      <div className="jjui-page-header__titleline">
        {onBack ? (
          <Button
            type="text"
            icon={<ArrowLeftOutlined />}
            aria-label="返回"
            onClick={onBack}
            className="jjui-page-header__back"
          />
        ) : null}
        <h1 className="jjui-page-header__title">{title}</h1>
      </div>
      {description ? <p className="jjui-page-header__description">{description}</p> : null}
    </header>
  );
}
